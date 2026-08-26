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

    @Test("Runs the shafts through detached outline arrowheads around the framed avatar")
    @MainActor
    func horizontalArrowAppearance() {
        let avatar = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let image = MenuBarIconRenderer.image(for: "", avatar: avatar)
        let bitmap = bitmap(for: image)

        #expect(image.size == NSSize(width: 32, height: 20))
        #expect(image.isTemplate == false)
        #expect(MenuBarIconRenderer.avatarRect == NSRect(x: 9, y: 3, width: 14, height: 14))
        #expect(isBlack(bitmap.colorAt(x: 2, y: 7)))
        #expect(isBlack(bitmap.colorAt(x: 29, y: 5)))
        #expect(isBlack(bitmap.colorAt(x: 3, y: 10)))
        #expect(isBlack(bitmap.colorAt(x: 28, y: 6)))
        #expect(isBlack(bitmap.colorAt(x: 4, y: 12)))
        #expect(isTransparent(bitmap.colorAt(x: 25, y: 3)))
        #expect(isNotOpaque(bitmap.colorAt(x: 7, y: 16)))
        #expect(isBlack(bitmap.colorAt(x: 8, y: 10)))
        #expect(isTransparent(bitmap.colorAt(x: 1, y: 9)))
        #expect(isTransparent(bitmap.colorAt(x: 7, y: 1)))
        #expect(isRed(bitmap.colorAt(x: 16, y: 10)))
    }

    @Test("Keeps the account prefix centered between the arrows")
    @MainActor
    func accountPrefixAppearance() {
        let image = MenuBarIconRenderer.image(for: "AB", avatar: nil)
        let prefixBitmap = bitmap(for: image)
        let badgePixels = (7..<25).flatMap { x in
            (1..<19).compactMap { y in prefixBitmap.colorAt(x: x, y: y) }
        }

        #expect(image.isTemplate == false)
        #expect(image.size == NSSize(width: 32, height: 20))
        #expect(isBlack(prefixBitmap.colorAt(x: 8, y: 4)))
        #expect(isTransparent(prefixBitmap.colorAt(x: 7, y: 1)))
        #expect(badgePixels.contains(where: isWhite))
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
