import Testing
@testable import GitHubAccountSwitcherCore

@Suite("Global Git identity")
struct GitConfigClientTests {
    @Test("Reads and updates the global commit identity")
    func readsAndUpdatesGlobalIdentity() throws {
        var commands: [[String]] = []
        let git = GitConfigClient { arguments in
            commands.append(arguments)
            if arguments.last == "user.name" {
                return CommandOutput(exitCode: 0, standardOutput: "nayooti", standardError: "")
            }
            if arguments.last == "user.email" {
                return CommandOutput(exitCode: 0, standardOutput: "nayooti@gmail.com", standardError: "")
            }
            return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
        }

        #expect(
            try git.globalIdentity()
                == GitIdentitySnapshot(name: "nayooti", email: "nayooti@gmail.com")
        )
        try git.setGlobalIdentity(
            GitIdentity(name: "Mobile Pur", email: "123456+mobilepur@users.noreply.github.com")
        )

        #expect(commands == [
            ["config", "--global", "--get", "user.name"],
            ["config", "--global", "--get", "user.email"],
            ["config", "--global", "user.name", "Mobile Pur"],
            ["config", "--global", "user.email", "123456+mobilepur@users.noreply.github.com"],
        ])
    }

    @Test("Restores missing global identity values")
    func restoresMissingValues() throws {
        var commands: [[String]] = []
        let git = GitConfigClient { arguments in
            commands.append(arguments)
            return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
        }

        try git.restoreGlobalIdentity(GitIdentitySnapshot(name: nil, email: nil))

        #expect(commands == [
            ["config", "--global", "--unset-all", "user.name"],
            ["config", "--global", "--unset-all", "user.email"],
        ])
    }

    @Test("Restoring the email is attempted when restoring the name fails")
    func restoreAttemptsEveryIdentityValue() {
        var commands: [[String]] = []
        let git = GitConfigClient { arguments in
            commands.append(arguments)
            if arguments == ["config", "--global", "user.name", "nayooti"] {
                return CommandOutput(exitCode: 1, standardOutput: "", standardError: "name failed")
            }
            return CommandOutput(exitCode: 0, standardOutput: "", standardError: "")
        }

        #expect(throws: (any Error).self) {
            try git.restoreGlobalIdentity(
                GitIdentitySnapshot(name: "nayooti", email: "nayooti@gmail.com")
            )
        }
        #expect(commands == [
            ["config", "--global", "user.name", "nayooti"],
            ["config", "--global", "user.email", "nayooti@gmail.com"],
        ])
    }
}
