import Foundation
import Testing
@testable import GitHubAccountSwitcherCore

@Suite("Account switching")
struct SwitchingTests {
    @Test("Use switches GitHub CLI, SSH, and the global Git identity")
    func useSwitchesAllAccountState() throws {
        try withFixture { fixture in
            try fixture.prepareMapping()
            var ghCommands: [[String]] = []
            let gh = fixture.gh { ghCommands.append($0) }
            let git = GitConfigFixture()

            let result = CLI.run(
                arguments: ["use", "mobilepur"],
                ghClient: gh,
                sshManager: fixture.manager,
                gitConfig: git.client
            )

            let config = try String(contentsOf: fixture.manager.managedConfigURL, encoding: .utf8)
            #expect(result == .init(exitCode: 0, output: "Active GitHub account: mobilepur"))
            #expect(ghCommands == [
                ["auth", "switch", "--hostname", "github.com", "--user", "mobilepur"],
                ["api", "--hostname", "github.com", "user"],
            ])
            #expect(config.contains("IdentityFile \"\(fixture.keyURL.path)\""))
            #expect(config.contains("IdentitiesOnly yes"))
            #expect(git.values == [
                "user.name": "Mobile Pur",
                "user.email": "123456+mobilepur@users.noreply.github.com",
            ])
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
                sshManager: fixture.manager,
                gitConfig: GitConfigFixture().client
            )

            let restored = try String(contentsOf: fixture.manager.managedConfigURL, encoding: .utf8)
            #expect(result == .init(exitCode: 1, output: "switch failed"))
            #expect(restored == previous)
        }
    }

    @Test("Use restores all account state when updating Git identity fails")
    func useRollsBackAllStateWhenGitIdentityFails() throws {
        try withFixture { fixture in
            try fixture.prepareMapping()
            let previousSSH = "previous config\n"
            try previousSSH.write(to: fixture.manager.managedConfigURL, atomically: true, encoding: .utf8)
            var ghCommands: [[String]] = []
            let gh = fixture.gh { ghCommands.append($0) }
            let git = GitConfigFixture(failingEmail: "123456+mobilepur@users.noreply.github.com")

            let result = CLI.run(
                arguments: ["use", "mobilepur"],
                ghClient: gh,
                sshManager: fixture.manager,
                gitConfig: git.client
            )

            let restoredSSH = try String(contentsOf: fixture.manager.managedConfigURL, encoding: .utf8)
            #expect(result.exitCode == 1)
            #expect(result.output == "git identity failed")
            #expect(restoredSSH == previousSSH)
            #expect(ghCommands == [
                ["auth", "switch", "--hostname", "github.com", "--user", "mobilepur"],
                ["api", "--hostname", "github.com", "user"],
                ["auth", "switch", "--hostname", "github.com", "--user", "nayooti"],
            ])
            #expect(git.values == [
                "user.name": "nayooti",
                "user.email": "nayooti@gmail.com",
            ])
        }
    }

    @Test("Use restores GitHub CLI and SSH when profile lookup fails")
    func useRollsBackAccountStateWhenProfileLookupFails() throws {
        try withFixture { fixture in
            try fixture.prepareMapping()
            let previousSSH = "previous config\n"
            try previousSSH.write(to: fixture.manager.managedConfigURL, atomically: true, encoding: .utf8)
            var ghCommands: [[String]] = []
            let gh = GHClient { arguments in
                if arguments == ["auth", "status", "--hostname", "github.com", "--json", "hosts"] {
                    return fixture.statusOutput
                }
                ghCommands.append(arguments)
                if arguments == ["api", "--hostname", "github.com", "user"] {
                    return CommandOutput(exitCode: 1, standardOutput: "", standardError: "profile failed")
                }
                return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
            }
            let git = GitConfigFixture()

            let result = CLI.run(
                arguments: ["use", "mobilepur"],
                ghClient: gh,
                sshManager: fixture.manager,
                gitConfig: git.client
            )

            let restoredSSH = try String(contentsOf: fixture.manager.managedConfigURL, encoding: .utf8)
            #expect(result == .init(exitCode: 1, output: "profile failed"))
            #expect(restoredSSH == previousSSH)
            #expect(ghCommands == [
                ["auth", "switch", "--hostname", "github.com", "--user", "mobilepur"],
                ["api", "--hostname", "github.com", "user"],
                ["auth", "switch", "--hostname", "github.com", "--user", "nayooti"],
            ])
            #expect(git.values == [
                "user.name": "nayooti",
                "user.email": "nayooti@gmail.com",
            ])
        }
    }

    @Test("Use continues restoring account state when Git identity rollback fails")
    func useContinuesRollbackAfterGitRestoreFailure() throws {
        try withFixture { fixture in
            try fixture.prepareMapping()
            let previousSSH = "previous config\n"
            try previousSSH.write(to: fixture.manager.managedConfigURL, atomically: true, encoding: .utf8)
            var ghCommands: [[String]] = []
            let gh = fixture.gh { ghCommands.append($0) }
            let git = GitConfigFixture(
                failingEmail: "123456+mobilepur@users.noreply.github.com",
                failingName: "nayooti"
            )

            let result = CLI.run(
                arguments: ["use", "mobilepur"],
                ghClient: gh,
                sshManager: fixture.manager,
                gitConfig: git.client
            )

            let restoredSSH = try String(contentsOf: fixture.manager.managedConfigURL, encoding: .utf8)
            #expect(result.exitCode == 1)
            #expect(
                result.output
                    == "git identity failed Rollback also failed: git identity rollback failed"
            )
            #expect(restoredSSH == previousSSH)
            #expect(ghCommands == [
                ["auth", "switch", "--hostname", "github.com", "--user", "mobilepur"],
                ["api", "--hostname", "github.com", "user"],
                ["auth", "switch", "--hostname", "github.com", "--user", "nayooti"],
            ])
            #expect(git.values["user.email"] == "nayooti@gmail.com")
        }
    }

    @Test("Use requires an SSH mapping")
    func useRequiresMapping() throws {
        try withFixture { fixture in
            let result = CLI.run(
                arguments: ["use", "mobilepur"],
                ghClient: fixture.gh(),
                sshManager: fixture.manager,
                gitConfig: GitConfigFixture().client
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
                standardOutput: #"{"hosts":{"github.com":[{"active":true,"login":"nayooti"},{"active":false,"login":"mobilepur"}]}}"#,
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
                if arguments == ["api", "--hostname", "github.com", "user"] {
                    return CommandOutput(
                        exitCode: 0,
                        standardOutput: #"{"id":123456,"login":"mobilepur","name":"Mobile Pur"}"#,
                        standardError: ""
                    )
                }
                return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
            }
        }
    }

    private final class GitConfigFixture {
        var values: [String: String] = [
            "user.name": "nayooti",
            "user.email": "nayooti@gmail.com",
        ]
        let failingEmail: String?
        let failingName: String?

        init(failingEmail: String? = nil, failingName: String? = nil) {
            self.failingEmail = failingEmail
            self.failingName = failingName
        }

        var client: GitConfigClient {
            GitConfigClient { [self] arguments in
                if arguments.starts(with: ["config", "--global", "--get"]),
                   let key = arguments.last {
                    guard let value = values[key] else {
                        return CommandOutput(exitCode: 1, standardOutput: "", standardError: "")
                    }
                    return CommandOutput(exitCode: 0, standardOutput: value, standardError: "")
                }
                if arguments.starts(with: ["config", "--global", "--unset-all"]),
                   let key = arguments.last {
                    values.removeValue(forKey: key)
                    return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
                }
                if arguments.count == 4 {
                    let key = arguments[2]
                    let value = arguments[3]
                    if key == "user.email", value == failingEmail {
                        return CommandOutput(exitCode: 1, standardOutput: "", standardError: "git identity failed")
                    }
                    if key == "user.name", value == failingName {
                        return CommandOutput(
                            exitCode: 1,
                            standardOutput: "",
                            standardError: "git identity rollback failed"
                        )
                    }
                    values[key] = value
                    return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
                }
                return CommandOutput(exitCode: 1, standardOutput: "", standardError: "unexpected git command")
            }
        }
    }
}
