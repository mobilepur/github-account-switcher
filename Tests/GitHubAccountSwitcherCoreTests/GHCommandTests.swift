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

    @Test("Use delegates account switching to GitHub CLI")
    func useDelegatesToGitHubCLI() {
        var receivedArguments: [String] = []
        let gh = GHClient { arguments in
            receivedArguments = arguments
            return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
        }

        let result = CLI.run(arguments: ["use", "nayooti"], ghClient: gh)

        #expect(receivedArguments == ["auth", "switch", "--hostname", "github.com", "--user", "nayooti"])
        #expect(result == .init(exitCode: 0, output: "Active GitHub account: nayooti"))
    }

    @Test("Use surfaces a GitHub CLI failure")
    func useSurfacesGitHubCLIFailure() {
        let gh = GHClient { _ in
            CommandOutput(exitCode: 1, standardOutput: "", standardError: "account not found")
        }

        let result = CLI.run(arguments: ["use", "missing"], ghClient: gh)

        #expect(result == .init(exitCode: 1, output: "account not found"))
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
