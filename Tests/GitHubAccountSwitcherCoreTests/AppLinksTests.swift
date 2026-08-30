import Testing
@testable import GitHubAccountSwitcherCore

@Suite("App links")
struct AppLinksTests {
    @Test("App versions open their matching GitHub release notes")
    func appVersionOpensMatchingReleaseNotes() {
        #expect(
            AppLinks.releaseNotes(version: "0.1.6").absoluteString
                == "https://github.com/mobilepur/github-account-switcher/releases/tag/v0.1.6"
        )
    }

    @Test("Problem reports open a new GitHub issue")
    func reportProblemOpensNewIssue() {
        #expect(AppLinks.newIssue.absoluteString == "https://github.com/mobilepur/github-account-switcher/issues/new")
    }

    @Test("Account authentication opens the GitHub device sign-in page")
    func accountAuthenticationOpensDeviceSignIn() {
        #expect(AppLinks.deviceSignIn.absoluteString == "https://github.com/login/device")
    }
}
