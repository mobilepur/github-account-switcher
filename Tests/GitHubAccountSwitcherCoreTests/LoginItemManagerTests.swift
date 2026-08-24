import Foundation
import Testing
@testable import GitHubAccountSwitcherCore

@Suite("Login item")
struct LoginItemManagerTests {
    @Test("Enabling and disabling writes and removes the launch agent")
    func toggleLoginItem() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let plistURL = directory.appending(path: "com.mobilepur.gh-switcher.plist")
        let manager = LoginItemManager(
            plistURL: plistURL,
            executablePath: "/opt/homebrew/bin/gh-switcher-menubar"
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        try manager.setEnabled(true)

        #expect(manager.isEnabled)
        let data = try Data(contentsOf: plistURL)
        let plist = try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        #expect(plist["Label"] as? String == "com.mobilepur.github-account-switcher")
        #expect(plist["ProgramArguments"] as? [String] == ["/opt/homebrew/bin/gh-switcher-menubar"])
        #expect(plist["RunAtLoad"] as? Bool == true)
        #expect(
            (plist["EnvironmentVariables"] as? [String: String])?["PATH"]
                == "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        )

        try manager.setEnabled(false)

        #expect(!manager.isEnabled)
    }
}
