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

struct GitIdentity: Equatable, Sendable {
    let name: String
    let email: String
}

private struct GHUser: Decodable {
    let id: Int
    let login: String
    let name: String?
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

    func gitIdentity() throws -> GitIdentity {
        let output = run(["api", "--hostname", "github.com", "user"])
        guard output.exitCode == 0 else {
            throw GHClientError.message(output.message)
        }

        let user = try JSONDecoder().decode(GHUser.self, from: Data(output.standardOutput.utf8))
        let profileName = user.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return GitIdentity(
            name: profileName.flatMap { $0.isEmpty ? nil : $0 } ?? user.login,
            email: "\(user.id)+\(user.login)@users.noreply.github.com"
        )
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

public final class GHAuthentication: @unchecked Sendable {
    private let executableURL: URL
    private let arguments: [String]
    let environment: [String: String]
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    init(
        executableURL: URL,
        arguments: [String],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
    }

    public static var live: GHAuthentication {
        let arguments = [
            "auth", "login", "--hostname", "github.com", "--web", "--clipboard", "--skip-ssh-key",
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["GH_BROWSER"] = "/usr/bin/true"
        let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"]
        if let executable = candidates.first(where: FileManager.default.fileExists(atPath:)) {
            return GHAuthentication(
                executableURL: URL(fileURLWithPath: executable),
                arguments: arguments,
                environment: environment
            )
        }
        return GHAuthentication(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["gh"] + arguments,
            environment: environment
        )
    }

    public var wasCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func run() throws {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = standardOutput
        process.standardError = standardError

        lock.lock()
        if cancelled {
            lock.unlock()
            throw GHClientError.message("Sign-in cancelled.")
        }
        do {
            try process.run()
            self.process = process
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }

        process.waitUntilExit()
        let wasCancelled = self.wasCancelled
        lock.lock()
        self.process = nil
        lock.unlock()

        guard !wasCancelled else {
            throw GHClientError.message("Sign-in cancelled.")
        }
        guard process.terminationStatus == 0 else {
            throw GHClientError.message(
                commandMessage(
                    standardOutput.fileHandleForReading.readString(),
                    standardError.fileHandleForReading.readString()
                )
            )
        }
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        let process = process
        lock.unlock()
        process?.terminate()
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

private func commandMessage(_ standardOutput: String, _ standardError: String) -> String {
    let error = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
    if !error.isEmpty { return error }

    let output = standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    return output.isEmpty ? "GitHub CLI command failed." : output
}

private extension FileHandle {
    func readString() -> String {
        String(decoding: readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
