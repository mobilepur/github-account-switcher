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
        run(arguments: arguments, ghClient: .live, sshManager: .live)
    }

    static func run(arguments: [String], ghClient: GHClient) -> Result {
        run(arguments: arguments, ghClient: ghClient, sshManager: .live)
    }

    static func run(arguments: [String], ghClient: GHClient, sshManager: SSHManager) -> Result {
        if arguments == ["version"] {
            return Result(exitCode: 0, output: "gh-switcher 0.1.1")
        }
        if arguments == ["accounts"] {
            return accounts(using: ghClient)
        }
        if arguments == ["current"] {
            return current(using: ghClient)
        }
        if arguments.count == 2, arguments[0] == "use" {
            return use(login: arguments[1], ghClient: ghClient, sshManager: sshManager)
        }
        if arguments == ["ssh", "mappings"] {
            return sshMappings(using: sshManager)
        }
        if arguments == ["setup"] {
            do {
                try sshManager.setup()
                return Result(exitCode: 0, output: "SSH integration configured.")
            } catch {
                return failure(error)
            }
        }
        if arguments.count == 3, arguments[0...1] == ["ssh", "unlink"] {
            return unlinkSSH(login: arguments[2], using: sshManager)
        }
        if arguments.count >= 4, arguments[0...1] == ["ssh", "link"] {
            return linkSSH(
                arguments: Array(arguments.dropFirst(2)),
                ghClient: ghClient,
                sshManager: sshManager
            )
        }
        return help(exitCode: arguments.isEmpty ? 0 : 1)
    }

    private static func sshMappings(using manager: SSHManager) -> Result {
        do {
            let mappings = try manager.mappings()
            guard !mappings.isEmpty else {
                return Result(exitCode: 0, output: "No SSH keys linked.")
            }
            let rows = mappings.sorted(by: { $0.key < $1.key }).map { login, mapping in
                "\(login)\t\(mapping.alias ?? "-")\t\(mapping.keyPath)"
            }
            return Result(exitCode: 0, output: (["GITHUB ACCOUNT\tALIAS\tSSH KEY"] + rows).joined(separator: "\n"))
        } catch {
            return failure(error)
        }
    }

    private static func linkSSH(arguments: [String], ghClient: GHClient, sshManager: SSHManager) -> Result {
        guard arguments.count == 2 || (arguments.count == 4 && arguments[2] == "--alias") else {
            return Result(exitCode: 1, output: "Usage: gh-switcher ssh link <login> <key-path> [--alias <alias>]")
        }
        let login = arguments[0]
        let alias = arguments.count == 4 ? arguments[3] : nil
        do {
            guard try ghClient.accounts().contains(where: { $0.login == login }) else {
                return Result(exitCode: 1, output: "GitHub account '\(login)' is not authenticated in gh.")
            }
            try sshManager.link(login: login, keyPath: arguments[1], alias: alias)
            return Result(exitCode: 0, output: "Linked SSH key for \(login).")
        } catch {
            return failure(error)
        }
    }

    private static func unlinkSSH(login: String, using manager: SSHManager) -> Result {
        do {
            try manager.unlink(login: login)
            return Result(exitCode: 0, output: "Unlinked SSH key for \(login).")
        } catch {
            return failure(error)
        }
    }

    private static func accounts(using ghClient: GHClient) -> Result {
        do {
            let accounts = try ghClient.accounts()
            guard !accounts.isEmpty else {
                return Result(exitCode: 0, output: "No GitHub accounts.")
            }

            let rows = accounts.map { "\($0.active ? "*" : " ") \($0.login)" }
            return Result(exitCode: 0, output: rows.joined(separator: "\n"))
        } catch {
            return failure(error)
        }
    }

    private static func current(using ghClient: GHClient) -> Result {
        do {
            guard let account = try ghClient.accounts().first(where: \.active) else {
                return Result(exitCode: 0, output: "No active GitHub account.")
            }
            return Result(exitCode: 0, output: account.login)
        } catch {
            return failure(error)
        }
    }

    private static func use(login: String, ghClient: GHClient, sshManager: SSHManager) -> Result {
        do {
            try AccountService.switchAccount(to: login, ghClient: ghClient, sshManager: sshManager)
            return Result(exitCode: 0, output: "Active GitHub account: \(login)")
        } catch {
            return failure(error)
        }
    }

    private static func failure(_ error: Error) -> Result {
        Result(exitCode: 1, output: error.localizedDescription)
    }

    private static func help(exitCode: Int32) -> Result {
        Result(
            exitCode: exitCode,
            output: """
            GitHub Account Switcher

            Usage: gh-switcher <command>

            Commands:
              accounts      List GitHub CLI accounts
              current       Show the active GitHub CLI account
              use <login>   Switch the active GitHub CLI account
              ssh mappings  List SSH key mappings
              ssh link <login> <key-path> [--alias <alias>]
                             Link an SSH key
              ssh unlink <login>
                             Remove an SSH key mapping
              setup          Configure the managed SSH include
              version       Show the current version
            """
        )
    }
}
