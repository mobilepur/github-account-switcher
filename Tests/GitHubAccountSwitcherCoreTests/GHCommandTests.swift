import Testing
@testable import GitHubAccountSwitcherCore

@Suite("GitHub CLI wrapper commands")
struct GHCommandTests {
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
