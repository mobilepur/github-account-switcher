import Foundation
import Testing
@testable import GitHubAccountSwitcherCore

@Suite("Account commands")
struct AccountCommandTests {
    @Test("Current reports when no account is active")
    func currentReportsNoActiveAccount() throws {
        try withFixture { fixture in
            let result = CLI.run(arguments: ["current"], configurationURL: fixture.configurationURL)

            #expect(result == .init(exitCode: 0, output: "No active account selected."))
        }
    }

    @Test("Accounts reports an empty configuration")
    func accountsReportsEmptyConfiguration() throws {
        try withFixture { fixture in
            let result = CLI.run(arguments: ["accounts"], configurationURL: fixture.configurationURL)

            #expect(result.exitCode == 0)
            #expect(result.output == "No GitHub accounts linked.")
        }
    }

    @Test("Accounts reads the configuration format from the previous version")
    func accountsReadsPreviousConfiguration() throws {
        try withFixture { fixture in
            let data = Data(#"[{"keyPath":"/tmp/id_ed25519","alias":"personal"}]"#.utf8)
            try data.write(to: fixture.configurationURL)

            let result = CLI.run(arguments: ["accounts"], configurationURL: fixture.configurationURL)

            #expect(result.exitCode == 0)
            #expect(result.output.contains("personal"))
            #expect(result.output.contains("/tmp/id_ed25519"))
        }
    }

    @Test("Link stores and lists an account with an alias")
    func linkStoresAccountWithAlias() throws {
        try withFixture { fixture in
            let keyURL = try fixture.createKey(named: "id_ed25519_work")

            let link = CLI.run(
                arguments: ["account", "link", keyURL.path, "--alias", "work"],
                configurationURL: fixture.configurationURL
            )
            let accounts = CLI.run(arguments: ["accounts"], configurationURL: fixture.configurationURL)

            #expect(link == .init(exitCode: 0, output: "Linked account 'work'."))
            #expect(accounts.exitCode == 0)
            #expect(accounts.output.contains("work"))
            #expect(accounts.output.contains(keyURL.path))
        }
    }

    @Test("Link uses the key filename when no alias is provided")
    func linkWithoutAliasUsesFilename() throws {
        try withFixture { fixture in
            let keyURL = try fixture.createKey(named: "id_ed25519_personal")

            let result = CLI.run(
                arguments: ["account", "link", keyURL.path],
                configurationURL: fixture.configurationURL
            )

            #expect(result == .init(exitCode: 0, output: "Linked account 'id_ed25519_personal'."))
        }
    }

    @Test("Link rejects a missing key")
    func linkRejectsMissingKey() throws {
        try withFixture { fixture in
            let result = CLI.run(
                arguments: ["account", "link", fixture.directory.appending(path: "missing").path],
                configurationURL: fixture.configurationURL
            )

            #expect(result.exitCode == 1)
            #expect(result.output == "SSH key does not exist or is not a file.")
        }
    }

    @Test("Link rejects duplicate key paths and aliases")
    func linkRejectsDuplicates() throws {
        try withFixture { fixture in
            let firstKey = try fixture.createKey(named: "id_first")
            let secondKey = try fixture.createKey(named: "id_second")
            _ = CLI.run(
                arguments: ["account", "link", firstKey.path, "--alias", "work"],
                configurationURL: fixture.configurationURL
            )

            let duplicateKey = CLI.run(
                arguments: ["account", "link", firstKey.path],
                configurationURL: fixture.configurationURL
            )
            let duplicateAlias = CLI.run(
                arguments: ["account", "link", secondKey.path, "--alias", "work"],
                configurationURL: fixture.configurationURL
            )

            #expect(duplicateKey == .init(exitCode: 1, output: "SSH key is already linked."))
            #expect(duplicateAlias == .init(exitCode: 1, output: "Alias is already in use."))
        }
    }

    @Test("Unlink removes an account by its display name")
    func unlinkRemovesAccount() throws {
        try withFixture { fixture in
            let keyURL = try fixture.createKey(named: "id_ed25519_work")
            _ = CLI.run(
                arguments: ["account", "link", keyURL.path, "--alias", "work"],
                configurationURL: fixture.configurationURL
            )

            let unlink = CLI.run(
                arguments: ["account", "unlink", "work"],
                configurationURL: fixture.configurationURL
            )
            let accounts = CLI.run(arguments: ["accounts"], configurationURL: fixture.configurationURL)

            #expect(unlink == .init(exitCode: 0, output: "Unlinked account 'work'."))
            #expect(accounts.output == "No GitHub accounts linked.")
        }
    }

    @Test("Use selects a linked account")
    func useSelectsLinkedAccount() throws {
        try withFixture { fixture in
            let keyURL = try fixture.createKey(named: "id_ed25519_work")
            _ = CLI.run(
                arguments: ["account", "link", keyURL.path, "--alias", "work"],
                configurationURL: fixture.configurationURL
            )

            let use = CLI.run(arguments: ["use", "work"], configurationURL: fixture.configurationURL)
            let current = CLI.run(arguments: ["current"], configurationURL: fixture.configurationURL)

            #expect(use == .init(exitCode: 0, output: "Active account: work"))
            #expect(current == .init(exitCode: 0, output: "work"))
        }
    }

    @Test("Use rejects an account that is not linked")
    func useRejectsUnknownAccount() throws {
        try withFixture { fixture in
            let result = CLI.run(arguments: ["use", "missing"], configurationURL: fixture.configurationURL)

            #expect(result == .init(exitCode: 1, output: "Account 'missing' is not linked."))
        }
    }

    @Test("Unlink clears the active account")
    func unlinkClearsActiveAccount() throws {
        try withFixture { fixture in
            let keyURL = try fixture.createKey(named: "id_ed25519_work")
            _ = CLI.run(
                arguments: ["account", "link", keyURL.path, "--alias", "work"],
                configurationURL: fixture.configurationURL
            )
            _ = CLI.run(arguments: ["use", "work"], configurationURL: fixture.configurationURL)

            _ = CLI.run(arguments: ["account", "unlink", "work"], configurationURL: fixture.configurationURL)
            let current = CLI.run(arguments: ["current"], configurationURL: fixture.configurationURL)

            #expect(current == .init(exitCode: 0, output: "No active account selected."))
        }
    }

    private func withFixture(_ body: (Fixture) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(Fixture(directory: directory))
    }

    private struct Fixture {
        let directory: URL

        var configurationURL: URL {
            directory.appending(path: "accounts.json")
        }

        func createKey(named name: String) throws -> URL {
            let url = directory.appending(path: name)
            try Data().write(to: url)
            return url
        }
    }
}
