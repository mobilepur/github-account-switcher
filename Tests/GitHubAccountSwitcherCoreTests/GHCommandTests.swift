import Foundation
import Testing
@testable import GitHubAccountSwitcherCore

@Suite("GitHub CLI wrapper commands")
struct GHCommandTests {
    @Test("Accounts are sorted lexicographically by login")
    func accountsAreSortedLexicographically() {
        let accounts = [
            GitHubAccount(login: "nayooti", isActive: false, sshKeyPath: nil, alias: nil),
            GitHubAccount(login: "MobilePur", isActive: true, sshKeyPath: nil, alias: nil),
        ]

        #expect(AccountService.sortedLexicographically(accounts).map(\.login) == ["MobilePur", "nayooti"])
    }

    @Test("GitHub account exposes its public avatar URL")
    func githubAvatarURLUsesLogin() {
        let account = GitHubAccount(login: "mobilepur", isActive: true, sshKeyPath: nil, alias: nil)

        #expect(account.avatarURL?.absoluteString == "https://github.com/mobilepur.png?size=80")
    }

    @Test("An account is configured only when it has an SSH key")
    func configuredAccountRequiresSSHKey() {
        let configured = GitHubAccount(login: "mobilepur", isActive: true, sshKeyPath: "/tmp/key", alias: nil)
        let unconfigured = GitHubAccount(login: "nayooti", isActive: false, sshKeyPath: nil, alias: nil)

        #expect(configured.isConfigured)
        #expect(!unconfigured.isConfigured)
    }

    @Test("Menu bar abbreviation uses the first two alias characters")
    func menuBarAbbreviationUsesAlias() {
        let account = GitHubAccount(
            login: "mobilepur",
            isActive: true,
            sshKeyPath: "/tmp/key",
            alias: "mobile"
        )

        #expect(account.menuBarAbbreviation == "MO")
    }

    @Test("Menu bar abbreviation falls back to the GitHub login")
    func menuBarAbbreviationUsesLogin() {
        let account = GitHubAccount(
            login: "nayooti",
            isActive: true,
            sshKeyPath: "/tmp/key",
            alias: nil
        )

        #expect(account.menuBarAbbreviation == "NA")
    }

    @Test("Accounts lists GitHub CLI accounts and marks the active account")
    func accountsListsGitHubCLIAccounts() {
        let gh = stubGH(statusJSON: statusJSON)

        let result = CLI.run(arguments: ["accounts"], ghClient: gh)

        #expect(result.exitCode == 0)
        #expect(result.output == "* mobilepur\n  nayooti")
    }

    @Test("Current displays the active GitHub CLI account")
    func currentDisplaysActiveAccount() {
        let gh = stubGH(statusJSON: statusJSON)

        let result = CLI.run(arguments: ["current"], ghClient: gh)

        #expect(result == .init(exitCode: 0, output: "mobilepur"))
    }

    @Test("Current reports when GitHub CLI has no active account")
    func currentReportsNoActiveAccount() {
        let gh = stubGH(statusJSON: #"{"hosts":{}}"#)

        let result = CLI.run(arguments: ["current"], ghClient: gh)

        #expect(result == .init(exitCode: 0, output: "No active GitHub account."))
    }

    @Test("Account authentication opens the GitHub CLI browser flow without changing SSH keys")
    func authenticateAccountUsesBrowserFlow() throws {
        var receivedArguments: [String] = []
        let gh = GHClient { arguments in
            receivedArguments = arguments
            return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
        }

        try gh.authenticateAccount()

        #expect(receivedArguments == [
            "auth", "login", "--hostname", "github.com", "--web", "--clipboard", "--skip-ssh-key",
        ])
    }

    @Test("Device sign-in waits for the app to open the browser")
    func authenticateAccountDoesNotOpenBrowserAutomatically() {
        #expect(GHAuthentication.live.environment["GH_BROWSER"] == "/usr/bin/true")
    }

    @Test("Account authentication surfaces GitHub CLI errors")
    func authenticateAccountSurfacesFailure() {
        let gh = GHClient { _ in
            CommandOutput(exitCode: 1, standardOutput: "", standardError: "sign-in cancelled")
        }

        #expect(throws: (any Error).self) {
            try gh.authenticateAccount()
        }
    }

    @Test("A pending GitHub authentication can be cancelled")
    func authenticationCanBeCancelled() async throws {
        let authentication = GHAuthentication(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "sleep 30"]
        )
        let task = Task.detached {
            Result { try authentication.run() }
        }

        try await Task.sleep(for: .milliseconds(100))
        authentication.cancel()

        let result = await task.value
        #expect(throws: (any Error).self) {
            try result.get()
        }
        #expect(authentication.wasCancelled)
    }

    private var statusJSON: String {
        #"{"hosts":{"github.com":[{"state":"success","active":true,"host":"github.com","login":"mobilepur","tokenSource":"keyring","scopes":"repo","gitProtocol":"https"},{"state":"success","active":false,"host":"github.com","login":"nayooti","tokenSource":"keyring","scopes":"repo","gitProtocol":"https"}]}}"#
    }

    private func stubGH(statusJSON: String) -> GHClient {
        GHClient { arguments in
            #expect(arguments == ["auth", "status", "--hostname", "github.com", "--json", "hosts"])
            return CommandOutput(exitCode: 0, standardOutput: statusJSON, standardError: "")
        }
    }
}
