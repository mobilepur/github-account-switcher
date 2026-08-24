import Foundation
import Testing
@testable import GitHubAccountSwitcherCore

@Suite("SSH mappings")
struct SSHMappingTests {
    @Test("Link stores an SSH key for a GitHub CLI account")
    func linkStoresMapping() throws {
        try withFixture { fixture in
            let key = try fixture.createKey("id_work")
            let result = CLI.run(
                arguments: ["ssh", "link", "mobilepur", key.path, "--alias", "work"],
                ghClient: fixture.gh,
                sshManager: fixture.manager
            )

            #expect(result == .init(exitCode: 0, output: "Linked SSH key for mobilepur."))
            #expect(try fixture.manager.mappings()["mobilepur"] == SSHMapping(keyPath: key.path, alias: "work"))
        }
    }

    @Test("Link rejects an unknown GitHub CLI account")
    func linkRejectsUnknownAccount() throws {
        try withFixture { fixture in
            let key = try fixture.createKey("id_unknown")
            let result = CLI.run(
                arguments: ["ssh", "link", "unknown", key.path],
                ghClient: fixture.gh,
                sshManager: fixture.manager
            )

            #expect(result == .init(exitCode: 1, output: "GitHub account 'unknown' is not authenticated in gh."))
        }
    }

    @Test("Link rejects a public key file")
    func linkRejectsPublicKey() throws {
        try withFixture { fixture in
            let key = try fixture.createKey("id_work.pub")
            let result = CLI.run(
                arguments: ["ssh", "link", "mobilepur", key.path],
                ghClient: fixture.gh,
                sshManager: fixture.manager
            )

            #expect(result == .init(exitCode: 1, output: "Select the private SSH key, not the .pub file."))
        }
    }

    @Test("Link rejects SSH configuration files", arguments: ["config", "known_hosts", "known_hosts.old"])
    func linkRejectsConfigurationFile(name: String) throws {
        try withFixture { fixture in
            let file = try fixture.createKey(name)
            let result = CLI.run(
                arguments: ["ssh", "link", "mobilepur", file.path],
                ghClient: fixture.gh,
                sshManager: fixture.manager
            )

            #expect(result == .init(exitCode: 1, output: "Select a private SSH key, not config or known_hosts."))
        }
    }

    @Test("Mappings lists aliases and key paths")
    func mappingsListsStoredValues() throws {
        try withFixture { fixture in
            let key = try fixture.createKey("id_work")
            try fixture.manager.link(login: "mobilepur", keyPath: key.path, alias: nil)

            let result = CLI.run(
                arguments: ["ssh", "mappings"],
                ghClient: fixture.gh,
                sshManager: fixture.manager
            )

            #expect(result.exitCode == 0)
            #expect(result.output.contains("mobilepur"))
            #expect(result.output.contains(key.path))
        }
    }

    @Test("Unlink removes an SSH mapping")
    func unlinkRemovesMapping() throws {
        try withFixture { fixture in
            let key = try fixture.createKey("id_work")
            try fixture.manager.link(login: "mobilepur", keyPath: key.path, alias: nil)

            let result = CLI.run(
                arguments: ["ssh", "unlink", "mobilepur"],
                ghClient: fixture.gh,
                sshManager: fixture.manager
            )

            #expect(result == .init(exitCode: 0, output: "Unlinked SSH key for mobilepur."))
            #expect(try fixture.manager.mappings().isEmpty)
        }
    }

    @Test("Setup preserves and backs up the SSH config")
    func setupPreservesAndBacksUpConfig() throws {
        try withFixture { fixture in
            let original = "Host existing\n  HostName example.com\n"
            try original.write(to: fixture.manager.userConfigURL, atomically: true, encoding: .utf8)

            try fixture.manager.setup()

            let updated = try String(contentsOf: fixture.manager.userConfigURL, encoding: .utf8)
            let backup = try String(contentsOf: fixture.manager.backupConfigURL, encoding: .utf8)
            #expect(updated.hasPrefix("Include \"\(fixture.manager.managedConfigURL.path)\"\n"))
            #expect(updated.contains(original))
            #expect(backup == original)
        }
    }

    @Test("Setup is idempotent")
    func setupIsIdempotent() throws {
        try withFixture { fixture in
            try fixture.manager.setup()
            try fixture.manager.setup()

            let config = try String(contentsOf: fixture.manager.userConfigURL, encoding: .utf8)
            #expect(config.components(separatedBy: "Include ").count == 2)
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

        var manager: SSHManager {
            SSHManager(
                mappingsURL: directory.appending(path: "mappings.json"),
                managedConfigURL: directory.appending(path: "managed-ssh-config"),
                userConfigURL: directory.appending(path: "ssh-config")
            )
        }

        var gh: GHClient {
            GHClient { _ in
                CommandOutput(
                    exitCode: 0,
                    standardOutput: #"{"hosts":{"github.com":[{"active":true,"login":"mobilepur"}]}}"#,
                    standardError: ""
                )
            }
        }

        func createKey(_ name: String) throws -> URL {
            let url = directory.appending(path: name)
            try Data().write(to: url)
            return url
        }
    }
}
