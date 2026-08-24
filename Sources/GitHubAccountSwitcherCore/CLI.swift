import Foundation

public enum CLI {
    public struct Result: Equatable, Sendable {
        public let exitCode: Int32
        public let output: String

        public init(exitCode: Int32, output: String) {
            self.exitCode = exitCode
            self.output = output
        }
    }

    public static func run(arguments: [String]) -> Result {
        run(arguments: arguments, configurationURL: defaultConfigurationURL)
    }

    static func run(arguments: [String], configurationURL: URL) -> Result {
        if arguments == ["version"] {
            return Result(exitCode: 0, output: "gh-switcher 0.1.0")
        }

        if arguments == ["accounts"] {
            return listAccounts(configurationURL: configurationURL)
        }

        if arguments == ["current"] {
            return currentAccount(configurationURL: configurationURL)
        }

        if arguments.count == 2, arguments[0] == "use" {
            return useAccount(named: arguments[1], configurationURL: configurationURL)
        }

        if arguments.count >= 3, arguments[0...1] == ["account", "link"] {
            return linkAccount(arguments: Array(arguments.dropFirst(2)), configurationURL: configurationURL)
        }

        if arguments.count == 3, arguments[0...1] == ["account", "unlink"] {
            return unlinkAccount(named: arguments[2], configurationURL: configurationURL)
        }

        return help(exitCode: arguments.isEmpty ? 0 : 1)
    }

    private static var defaultConfigurationURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/GitHubAccountSwitcher", directoryHint: .isDirectory)
            .appending(path: "accounts.json")
    }

    private static func listAccounts(configurationURL: URL) -> Result {
        do {
            let accounts = try AccountStore(configurationURL: configurationURL).load().accounts
            guard !accounts.isEmpty else {
                return Result(exitCode: 0, output: "No GitHub accounts linked.")
            }

            let rows = accounts.map { "\($0.displayName)\t\($0.keyPath)" }
            return Result(exitCode: 0, output: (["NAME\tSSH KEY"] + rows).joined(separator: "\n"))
        } catch {
            return failure(error)
        }
    }

    private static func linkAccount(arguments: [String], configurationURL: URL) -> Result {
        guard arguments.count == 1 || (arguments.count == 3 && arguments[1] == "--alias") else {
            return Result(exitCode: 1, output: "Usage: gh-switcher account link <key-path> [--alias <alias>]")
        }

        let keyPath = NSString(string: arguments[0]).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: keyPath, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return Result(exitCode: 1, output: "SSH key does not exist or is not a file.")
        }

        let alias = arguments.count == 3 ? arguments[2] : nil
        guard alias?.isEmpty != true else {
            return Result(exitCode: 1, output: "Alias cannot be empty.")
        }

        do {
            let store = AccountStore(configurationURL: configurationURL)
            var configuration = try store.load()
            let account = Account(keyPath: keyPath, alias: alias)

            guard !configuration.accounts.contains(where: { $0.keyPath == keyPath }) else {
                return Result(exitCode: 1, output: "SSH key is already linked.")
            }
            if let alias, configuration.accounts.contains(where: { $0.displayName == alias }) {
                return Result(exitCode: 1, output: "Alias is already in use.")
            }
            guard !configuration.accounts.contains(where: { $0.displayName == account.displayName }) else {
                return Result(exitCode: 1, output: "Account name is already in use.")
            }

            configuration.accounts.append(account)
            try store.save(configuration)
            return Result(exitCode: 0, output: "Linked account '\(account.displayName)'.")
        } catch {
            return failure(error)
        }
    }

    private static func unlinkAccount(named name: String, configurationURL: URL) -> Result {
        do {
            let store = AccountStore(configurationURL: configurationURL)
            var configuration = try store.load()
            guard let index = configuration.accounts.firstIndex(where: { $0.displayName == name }) else {
                return Result(exitCode: 1, output: "Account '\(name)' is not linked.")
            }

            let removed = configuration.accounts.remove(at: index)
            if configuration.activeKeyPath == removed.keyPath {
                configuration.activeKeyPath = nil
            }
            try store.save(configuration)
            return Result(exitCode: 0, output: "Unlinked account '\(name)'.")
        } catch {
            return failure(error)
        }
    }

    private static func currentAccount(configurationURL: URL) -> Result {
        do {
            let configuration = try AccountStore(configurationURL: configurationURL).load()
            guard
                let activeKeyPath = configuration.activeKeyPath,
                let account = configuration.accounts.first(where: { $0.keyPath == activeKeyPath })
            else {
                return Result(exitCode: 0, output: "No active account selected.")
            }

            return Result(exitCode: 0, output: account.displayName)
        } catch {
            return failure(error)
        }
    }

    private static func useAccount(named name: String, configurationURL: URL) -> Result {
        do {
            let store = AccountStore(configurationURL: configurationURL)
            var configuration = try store.load()
            guard let account = configuration.accounts.first(where: { $0.displayName == name }) else {
                return Result(exitCode: 1, output: "Account '\(name)' is not linked.")
            }

            configuration.activeKeyPath = account.keyPath
            try store.save(configuration)
            return Result(exitCode: 0, output: "Active account: \(account.displayName)")
        } catch {
            return failure(error)
        }
    }

    private static func failure(_ error: Error) -> Result {
        Result(exitCode: 1, output: "Error: \(error.localizedDescription)")
    }

    private static func help(exitCode: Int32) -> Result {
        Result(
            exitCode: exitCode,
            output: """
            GitHub Account Switcher

            Usage: gh-switcher <command>

            Commands:
              accounts                              List linked accounts
              current                               Show the active account
              use <name>                            Select the active account
              account link <key-path> [--alias <alias>]
                                                    Link an SSH key
              account unlink <name>                 Unlink an account
              version                               Show the current version
            """
        )
    }
}
