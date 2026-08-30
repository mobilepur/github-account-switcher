import AppKit
import Testing
@testable import GitHubAccountSwitcherMenuBar

@Suite("Menu bar icon")
struct MenuBarIconRendererTests {
    @Test("Clears stale avatars while another account is loading")
    @MainActor
    func clearsStaleAvatarWhileLoading() {
        let state = ActiveAvatarState()
        let oldAvatar = NSImage(size: NSSize(width: 1, height: 1))
        let newAvatar = NSImage(size: NSSize(width: 1, height: 1))

        state.beginLoading(for: "old")
        state.finishLoading(oldAvatar, for: "old")
        state.beginLoading(for: "new")

        #expect(state.image == nil)

        state.finishLoading(oldAvatar, for: "old")
        #expect(state.image == nil)

        state.finishLoading(newAvatar, for: "new")
        #expect(state.image === newAvatar)
    }

    @Test("Cancelled avatar loads leave the current avatar unchanged")
    @MainActor
    func cancelledLoadLeavesCurrentAvatarUnchanged() async {
        let state = ActiveAvatarState()
        let currentAvatar = NSImage(size: NSSize(width: 1, height: 1))
        let staleAvatar = NSImage(size: NSSize(width: 1, height: 1))
        state.beginLoading(for: "current")
        state.finishLoading(currentAvatar, for: "current")

        let task = Task { @MainActor in
            await state.load(for: "stale") { staleAvatar }
        }
        task.cancel()
        await task.value

        #expect(state.image === currentAvatar)
    }

    @Test("Avatar downloads wait for connectivity")
    func avatarDownloadsWaitForConnectivity() {
        let configuration = AvatarLoader.sessionConfiguration()

        #expect(configuration.waitsForConnectivity)
    }

    @Test("Keeps the colored avatar in the compact adaptive icon")
    @MainActor
    func compactAvatarIconAppearance() {
        let avatar = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let image = MenuBarIconRenderer.image(for: "", avatar: avatar)
        let bitmap = bitmap(for: image)

        #expect(image.size == NSSize(width: 28, height: 18))
        #expect(image.isTemplate == false)
        #expect(MenuBarIconRenderer.avatarRect == NSRect(x: 7, y: 2, width: 14, height: 14))
        #expect(isOpaque(bitmap.colorAt(x: 2, y: 5)))
        #expect(isTransparent(bitmap.colorAt(x: 1, y: 8)))
        #expect(isRed(bitmap.colorAt(x: 14, y: 9)))
    }

    @Test("Keeps the account prefix centered between the arrows")
    @MainActor
    func accountPrefixAppearance() {
        let image = MenuBarIconRenderer.image(for: "AB", avatar: nil)
        let prefixBitmap = bitmap(for: image)
        let badgePixels = (6..<22).flatMap { x in
            (1..<17).compactMap { y in prefixBitmap.colorAt(x: x, y: y) }
        }

        #expect(image.isTemplate)
        #expect(image.size == NSSize(width: 28, height: 18))
        #expect(isOpaque(prefixBitmap.colorAt(x: 7, y: 4)))
        #expect(isTransparent(prefixBitmap.colorAt(x: 6, y: 1)))
        #expect(badgePixels.contains(where: isNotOpaque))
    }

    @MainActor
    private func bitmap(for image: NSImage) -> NSBitmapImageRep {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(image.size.width),
            pixelsHigh: Int(image.size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        bitmap.size = image.size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    private func isBlack(_ color: NSColor?) -> Bool {
        guard let color = color?.usingColorSpace(.deviceRGB) else { return false }
        return color.alphaComponent > 0.8
            && color.redComponent < 0.2
            && color.greenComponent < 0.2
            && color.blueComponent < 0.2
    }

    private func isOpaque(_ color: NSColor?) -> Bool {
        (color?.alphaComponent ?? 0) > 0.8
    }

    private func isAntialiasedBlack(_ color: NSColor?) -> Bool {
        guard let color = color?.usingColorSpace(.deviceRGB) else { return false }
        return color.alphaComponent > 0.2
            && color.alphaComponent < 0.8
            && color.redComponent < 0.2
            && color.greenComponent < 0.2
            && color.blueComponent < 0.2
    }

    private func isRed(_ color: NSColor?) -> Bool {
        guard let color = color?.usingColorSpace(.deviceRGB) else { return false }
        return color.alphaComponent > 0.8
            && color.redComponent > 0.8
            && color.greenComponent < 0.2
            && color.blueComponent < 0.2
    }

    private func isWhite(_ color: NSColor?) -> Bool {
        guard let color = color?.usingColorSpace(.deviceRGB) else { return false }
        return color.alphaComponent > 0.8
            && color.redComponent > 0.8
            && color.greenComponent > 0.8
            && color.blueComponent > 0.8
    }

    private func isTransparent(_ color: NSColor?) -> Bool {
        guard let color else { return false }
        return color.alphaComponent < 0.2
    }

    private func isNotOpaque(_ color: NSColor?) -> Bool {
        guard let color else { return false }
        return color.alphaComponent < 0.8
    }
}
