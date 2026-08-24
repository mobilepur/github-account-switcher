import Testing
@testable import GitHubAccountSwitcherCore

@Suite("App links")
struct AppLinksTests {
    @Test("Problem reports open a new GitHub issue")
    func reportProblemOpensNewIssue() {
        #expect(AppLinks.newIssue.absoluteString == "https://github.com/mobilepur/github-account-switcher/issues/new")
    }
}
