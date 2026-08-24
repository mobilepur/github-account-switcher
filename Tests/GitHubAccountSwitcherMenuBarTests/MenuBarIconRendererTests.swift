import AppKit
import Testing
@testable import GitHubAccountSwitcherMenuBar

@Suite("Menu bar icon")
struct MenuBarIconRendererTests {
    @Test("Uses a 30 point split black and white arrow")
    func splitArrowAppearance() {
        let image = MenuBarIconRenderer.image(for: "", avatar: nil)

        #expect(image.size == NSSize(width: 30, height: 20))
        #expect(image.isTemplate == false)

        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let left = bitmap.colorAt(x: 8, y: 10)!.usingColorSpace(NSColorSpace.deviceRGB)!
        let leftBorder = bitmap.colorAt(x: 8, y: 17)!.usingColorSpace(NSColorSpace.deviceRGB)!
        let right = bitmap.colorAt(x: 22, y: 10)!.usingColorSpace(NSColorSpace.deviceRGB)!

        #expect(left.redComponent > 0.9)
        #expect(left.greenComponent > 0.9)
        #expect(left.blueComponent > 0.9)
        #expect(leftBorder.redComponent < 0.5)
        #expect(leftBorder.greenComponent < 0.5)
        #expect(leftBorder.blueComponent < 0.5)
        #expect(right.redComponent < 0.1)
        #expect(right.greenComponent < 0.1)
        #expect(right.blueComponent < 0.1)
    }
}
