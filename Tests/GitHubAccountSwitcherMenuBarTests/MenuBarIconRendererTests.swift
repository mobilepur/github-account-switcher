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

    @Test("Uses a narrow adaptive arrow with an avatar-width center")
    func adaptiveArrowAppearance() {
        let image = MenuBarIconRenderer.image(for: "", avatar: nil)

        #expect(image.size == NSSize(width: 32, height: 20))
        #expect(image.isTemplate)
        #expect(MenuBarIconRenderer.shaftMaxX - MenuBarIconRenderer.shaftMinX == 14)
        #expect(MenuBarIconRenderer.avatarRect.width == 14)
        #expect(MenuBarIconRenderer.shaftMaxX - MenuBarIconRenderer.shaftMinX == MenuBarIconRenderer.avatarRect.width)
    }
}
