import Foundation
import GitHubAccountSwitcherCore

let result = CLI.run(arguments: Array(CommandLine.arguments.dropFirst()))
print(result.output)
exit(result.exitCode)
