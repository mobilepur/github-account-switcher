import Testing
@testable import GitHubAccountSwitcherCore

@Suite("CLI commands")
struct CLICommandTests {
    @Test("No arguments display help")
    func noArgumentsDisplayHelp() {
        let result = CLI.run(arguments: [])

        #expect(result.exitCode == 0)
        #expect(result.output.contains("Usage: gas"))
    }

    @Test("Version command displays the current version")
    func versionCommandDisplaysVersion() {
        let result = CLI.run(arguments: ["version"])

        #expect(result.exitCode == 0)
        #expect(result.output == "gas 0.1.0")
    }
}
