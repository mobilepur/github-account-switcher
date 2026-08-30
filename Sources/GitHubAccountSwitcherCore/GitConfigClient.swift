import Foundation

struct GitIdentitySnapshot: Equatable, Sendable {
    let name: String?
    let email: String?
}

struct GitConfigClient {
    let run: ([String]) -> CommandOutput

    func globalIdentity() throws -> GitIdentitySnapshot {
        GitIdentitySnapshot(
            name: try globalValue(for: "user.name"),
            email: try globalValue(for: "user.email")
        )
    }

    func setGlobalIdentity(_ identity: GitIdentity) throws {
        try setGlobalValue(identity.name, for: "user.name")
        try setGlobalValue(identity.email, for: "user.email")
    }

    func restoreGlobalIdentity(_ snapshot: GitIdentitySnapshot) throws {
        var errors: [String] = []
        restoreGlobalValue(snapshot.name, for: "user.name", errors: &errors)
        restoreGlobalValue(snapshot.email, for: "user.email", errors: &errors)
        if !errors.isEmpty {
            throw GitConfigError.message(errors.joined(separator: "; "))
        }
    }

    static var live: GitConfigClient {
        GitConfigClient { arguments in
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return CommandOutput(
                    exitCode: 1,
                    standardOutput: "",
                    standardError: error.localizedDescription
                )
            }

            return CommandOutput(
                exitCode: process.terminationStatus,
                standardOutput: standardOutput.fileHandleForReading.readGitConfigString(),
                standardError: standardError.fileHandleForReading.readGitConfigString()
            )
        }
    }

    private func globalValue(for key: String) throws -> String? {
        let output = run(["config", "--global", "--get", key])
        if output.exitCode == 0 {
            return output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if output.exitCode == 1 || output.exitCode == 5 {
            return nil
        }
        throw GitConfigError.message(output.gitConfigMessage)
    }

    private func setGlobalValue(_ value: String, for key: String) throws {
        let output = run(["config", "--global", key, value])
        guard output.exitCode == 0 else {
            throw GitConfigError.message(output.gitConfigMessage)
        }
    }

    private func restoreGlobalValue(_ value: String?, for key: String) throws {
        if let value {
            try setGlobalValue(value, for: key)
            return
        }

        let output = run(["config", "--global", "--unset-all", key])
        guard output.exitCode == 0 || output.exitCode == 1 || output.exitCode == 5 else {
            throw GitConfigError.message(output.gitConfigMessage)
        }
    }

    private func restoreGlobalValue(
        _ value: String?,
        for key: String,
        errors: inout [String]
    ) {
        do {
            try restoreGlobalValue(value, for: key)
        } catch {
            errors.append(error.localizedDescription)
        }
    }
}

private enum GitConfigError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(message): message
        }
    }
}

private extension CommandOutput {
    var gitConfigMessage: String {
        let error = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !error.isEmpty { return error }

        let output = standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? "Git configuration command failed." : output
    }
}

private extension FileHandle {
    func readGitConfigString() -> String {
        String(decoding: readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
