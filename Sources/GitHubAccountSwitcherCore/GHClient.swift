import Foundation

struct CommandOutput {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
}

struct GHAccount: Decodable {
    let active: Bool
    let login: String
}

struct GHClient {
    let run: ([String]) -> CommandOutput

    func accounts() throws -> [GHAccount] {
        let output = run(["auth", "status", "--hostname", "github.com", "--json", "hosts"])
        guard output.exitCode == 0 else {
            throw GHClientError.message(output.message)
        }

        let status = try JSONDecoder().decode(
            AuthenticationStatus.self,
            from: Data(output.standardOutput.utf8)
        )
        return status.hosts["github.com"] ?? []
    }

    func switchAccount(to login: String) throws {
        let output = run(["auth", "switch", "--hostname", "github.com", "--user", login])
        guard output.exitCode == 0 else {
            throw GHClientError.message(output.message)
        }
    }

    func authenticateAccount() throws {
        let output = run([
            "auth", "login", "--hostname", "github.com", "--web", "--clipboard", "--skip-ssh-key",
        ])
        guard output.exitCode == 0 else {
            throw GHClientError.message(output.message)
        }
    }

    static var live: GHClient { GHClient { arguments in
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"]
        if let executable = candidates.first(where: FileManager.default.fileExists(atPath:)) {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["gh"] + arguments
        }
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandOutput(exitCode: 1, standardOutput: "", standardError: error.localizedDescription)
        }

        return CommandOutput(
            exitCode: process.terminationStatus,
            standardOutput: standardOutput.fileHandleForReading.readString(),
            standardError: standardError.fileHandleForReading.readString()
        )
    } }

    private struct AuthenticationStatus: Decodable {
        let hosts: [String: [GHAccount]]
    }
}

private enum GHClientError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(message): message
        }
    }
}

private extension CommandOutput {
    var message: String {
        let error = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !error.isEmpty { return error }

        let output = standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? "GitHub CLI command failed." : output
    }
}

private extension FileHandle {
    func readString() -> String {
        String(decoding: readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
