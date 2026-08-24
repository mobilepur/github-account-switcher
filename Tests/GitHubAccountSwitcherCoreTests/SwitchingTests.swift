import Foundation
import Testing
@testable import GitHubAccountSwitcherCore

@Suite("Account switching")
struct SwitchingTests {
    @Test("Use switches GitHub CLI and the managed SSH key")
    func useSwitchesBothSystems() throws {
        try withFixture { fixture in
            try fixture.prepareMapping()
            var switchArguments: [String] = []
            let gh = fixture.gh { switchArguments = $0 }

            let result = CLI.run(
                arguments: ["use", "mobilepur"],
                ghClient: gh,
                sshManager: fixture.manager
            )

            let config = try String(contentsOf: fixture.manager.managedConfigURL, encoding: .utf8)
            #expect(result == .init(exitCode: 0, output: "Active GitHub account: mobilepur"))
            #expect(switchArguments == ["auth", "switch", "--hostname", "github.com", "--user", "mobilepur"])
            #expect(config.contains("IdentityFile \"\(fixture.keyURL.path)\""))
            #expect(config.contains("IdentitiesOnly yes"))
        }
    }

    @Test("Use restores SSH config when GitHub CLI switching fails")
    func useRollsBackSSHConfig() throws {
        try withFixture { fixture in
            try fixture.prepareMapping()
            let previous = "previous config\n"
            try previous.write(to: fixture.manager.managedConfigURL, atomically: true, encoding: .utf8)
            let gh = GHClient { arguments in
                if arguments.first == "auth", arguments.dropFirst().first == "status" {
                    return fixture.statusOutput
                }
                return CommandOutput(exitCode: 1, standardOutput: "", standardError: "switch failed")
            }

            let result = CLI.run(
                arguments: ["use", "mobilepur"],
                ghClient: gh,
                sshManager: fixture.manager
            )

            let restored = try String(contentsOf: fixture.manager.managedConfigURL, encoding: .utf8)
            #expect(result == .init(exitCode: 1, output: "switch failed"))
            #expect(restored == previous)
        }
    }

    @Test("Use requires an SSH mapping")
    func useRequiresMapping() throws {
        try withFixture { fixture in
            let result = CLI.run(
                arguments: ["use", "mobilepur"],
                ghClient: fixture.gh(),
                sshManager: fixture.manager
            )

            #expect(result == .init(exitCode: 1, output: "No SSH key is linked for mobilepur."))
        }
    }

    private func withFixture(_ body: (Fixture) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(Fixture(directory: directory))
    }

    private struct Fixture {
        let directory: URL

        var keyURL: URL { directory.appending(path: "id_mobilepur") }
        var manager: SSHManager {
            SSHManager(
                mappingsURL: directory.appending(path: "mappings.json"),
                managedConfigURL: directory.appending(path: "managed-config"),
                userConfigURL: directory.appending(path: "ssh-config")
            )
        }
        var statusOutput: CommandOutput {
            CommandOutput(
                exitCode: 0,
                standardOutput: #"{"hosts":{"github.com":[{"active":false,"login":"mobilepur"}]}}"#,
                standardError: ""
            )
        }

        func prepareMapping() throws {
            try Data().write(to: keyURL)
            try manager.link(login: "mobilepur", keyPath: keyURL.path, alias: nil)
            try manager.setup()
        }

        func gh(onSwitch: (([String]) -> Void)? = nil) -> GHClient {
            GHClient { arguments in
                if arguments.first == "auth", arguments.dropFirst().first == "status" {
                    return statusOutput
                }
                onSwitch?(arguments)
                return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
            }
        }
    }
}
