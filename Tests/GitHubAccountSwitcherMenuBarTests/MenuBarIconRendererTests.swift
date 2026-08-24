import AppKit
import Testing
@testable import GitHubAccountSwitcherMenuBar

@Suite("Menu bar icon")
struct MenuBarIconRendererTests {
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
