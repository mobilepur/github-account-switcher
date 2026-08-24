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
        if arguments.first == "version" {
            return Result(exitCode: 0, output: "gas 0.1.0")
        }

        return Result(
            exitCode: 0,
            output: """
            GitHub Account Switcher

            Usage: gas <command>

            Commands:
              version  Show the current version
            """
        )
    }
}
