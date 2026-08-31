import AppKit
import SwiftUI
import Testing
@testable import GitHubAccountSwitcherMenuBar

@Suite("Menu bar icon")
struct MenuBarIconRendererTests {
    @Test("Navigation rows activate from their empty space")
    @MainActor
    func navigationRowsUseFullWidthHitTarget() {
        var activationCount = 0
        let row = Button {
            activationCount += 1
        } label: {
            MainPanelNavigationLabel(title: "Open")
        }
        .buttonStyle(.plain)
        .frame(width: 212, height: 32)
        let hostingView = NSHostingView(rootView: row)
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 212, height: 32),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFront(nil)
        defer { window.close() }
        hostingView.layoutSubtreeIfNeeded()

        click(at: NSPoint(x: 106, y: 16), in: window)

        #expect(activationCount == 1)
    }

    @Test("Account Settings offer concise private-key help")
    func privateKeyHelpExplainsPushAuthentication() {
        #expect(
            SettingsCopy.privateKeyGuidance
                == "The linked SSH key authenticates Git pushes as this GitHub account."
        )
    }

    @Test("Account sign-in returns to the Settings window")
    @MainActor
    func accountSignInFindsSettingsWindow() {
        let otherWindow = NSWindow()
        otherWindow.title = "Other window"
        let settingsWindow = NSWindow()
        settingsWindow.title = "gh-switcher-menubar Settings"

        #expect(SettingsWindow.find(in: [otherWindow, settingsWindow]) === settingsWindow)
    }

    @Test("Account sign-in reserves room for its widget")
    func accountSignInUsesTallerSettingsWindow() {
        #expect(SettingsLayout.contentHeight(isAddingAccount: false) == 368)
        #expect(SettingsLayout.contentHeight(isAddingAccount: true) == 480)
    }

    @Test("Opening the device page keeps the sign-in widget visible")
    @MainActor
    func devicePageOpenConfigurationDoesNotActivateBrowser() {
        #expect(!GitHubDeviceBrowser.openConfiguration().activates)
    }

    @Test("GitHub device sign-in timeouts use a concise retry message")
    func deviceSignInTimeoutHasFriendlyMessage() {
        let error = NSError(
            domain: "GitHub CLI",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "One-time code copied to clipboard\nfailed to authenticate via web browser: context deadline exceeded"]
        )

        #expect(
            GitHubSignInFeedback.message(for: error)
                == "GitHub sign-in timed out. Click Add Account… to try again."
        )
    }

    @Test("GitHub device sign-in accepts only one-time codes")
    func parsesGitHubDeviceCode() {
        #expect(DeviceSignInCode.parse("AB12-CD34") == "AB12-CD34")
        #expect(DeviceSignInCode.parse("AB12CD34") == nil)
        #expect(DeviceSignInCode.parse("AB12-CD34\n") == nil)
    }

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
        #expect(MenuBarIconRenderer.avatarRect == NSRect(x: 7.5, y: 2.5, width: 13, height: 13))
        #expect(hasAlpha(bitmap.colorAt(x: 2, y: 5), approximately: 0.9))
        #expect(isTransparent(bitmap.colorAt(x: 1, y: 8)))
        #expect(isRed(bitmap.colorAt(x: 14, y: 9)))
    }

    @Test("Keeps the account prefix centered between the arrows")
    @MainActor
    func accountPrefixAppearance() {
        let image = MenuBarIconRenderer.image(for: "AB", avatar: nil)
        let prefixBitmap = bitmap(for: image)
        let baseIconBitmap = bitmap(for: MenuBarIconRenderer.image(for: "", avatar: nil))
        let badgePixels = (6..<22).flatMap { x in
            (1..<17).compactMap { y in prefixBitmap.colorAt(x: x, y: y) }
        }

        #expect(image.isTemplate)
        #expect(image.size == NSSize(width: 28, height: 18))
        #expect(hasAlpha(baseIconBitmap.colorAt(x: 14, y: 9), approximately: 0.9))
        #expect(isTransparent(prefixBitmap.colorAt(x: 6, y: 1)))
        #expect(badgePixels.contains(where: isNotOpaque))
    }

    @Test("Centers the larger account prefix in the badge")
    @MainActor
    func largerAccountPrefixAppearance() throws {
        let image = MenuBarIconRenderer.image(for: "MO", avatar: nil)
        let bitmap = bitmap(for: image)
        let glyphPixels = (8..<20).flatMap { x in
            (3..<15).compactMap { y -> NSPoint? in
                guard isTransparent(bitmap.colorAt(x: x, y: y)) else { return nil }
                return NSPoint(x: x, y: y)
            }
        }
        let minimumY = try #require(glyphPixels.map(\.y).min())
        let maximumY = try #require(glyphPixels.map(\.y).max())
        let glyphHeight = maximumY - minimumY + 1
        let glyphCenterY = (minimumY + maximumY + 1) / 2

        #expect(MenuBarIconRenderer.abbreviationFontSize == 10)
        #expect(glyphHeight >= 7)
        #expect(glyphCenterY == 8.5)
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
        (color?.alphaComponent ?? 0) >= 0.8
    }

    private func hasAlpha(_ color: NSColor?, approximately expectedAlpha: CGFloat) -> Bool {
        guard let color else { return false }
        return abs(color.alphaComponent - expectedAlpha) < 0.05
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

    @MainActor
    private func click(at point: NSPoint, in window: NSWindow) {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(
                with: type,
                location: point,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: type == .leftMouseDown ? 1 : 0
            )!
            window.sendEvent(event)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}
