import AppKit
import Testing
@testable import GitHubAccountSwitcherMenuBar

@Suite("Menu bar icon")
struct MenuBarIconRendererTests {
    @Test("Uses the system-adaptive 34 point arrow")
    func adaptiveArrowAppearance() {
        let image = MenuBarIconRenderer.image(for: "", avatar: nil)

        #expect(image.size == NSSize(width: 34, height: 20))
        #expect(image.isTemplate)
    }
}
