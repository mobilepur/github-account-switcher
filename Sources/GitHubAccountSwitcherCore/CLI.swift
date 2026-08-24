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
        run(arguments: arguments, ghClient: .live)
    }

    static func run(arguments: [String], ghClient: GHClient) -> Result {
        if arguments == ["version"] {
            return Result(exitCode: 0, output: "gh-switcher 0.1.0")
        }
        if arguments == ["accounts"] {
            return accounts(using: ghClient)
        }
        if arguments == ["current"] {
            return current(using: ghClient)
        }
        if arguments.count == 2, arguments[0] == "use" {
            return use(login: arguments[1], using: ghClient)
        }
        return help(exitCode: arguments.isEmpty ? 0 : 1)
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

    private static func use(login: String, using ghClient: GHClient) -> Result {
        do {
            try ghClient.switchAccount(to: login)
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
              version       Show the current version
            """
        )
    }
}
