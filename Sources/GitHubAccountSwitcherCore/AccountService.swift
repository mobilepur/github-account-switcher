import Foundation

public struct GitHubAccount: Identifiable, Sendable {
    public let login: String
    public let isActive: Bool
    public let sshKeyPath: String?
    public let alias: String?

    public var id: String { login }
    public var displayName: String { alias ?? login }
    public var isConfigured: Bool { sshKeyPath != nil }
    public var avatarURL: URL? { URL(string: "https://github.com/\(login).png?size=80") }
    public var menuBarAbbreviation: String {
        String(displayName.prefix(2)).uppercased()
    }
}

public enum AccountService {
    public static func accounts() throws -> [GitHubAccount] {
        let mappings = try SSHManager.live.mappings()
        let accounts = try GHClient.live.accounts().map { account in
            let mapping = mappings[account.login]
            return GitHubAccount(
                login: account.login,
                isActive: account.active,
                sshKeyPath: mapping?.keyPath,
                alias: mapping?.alias
            )
        }
        return sortedLexicographically(accounts)
    }

    static func sortedLexicographically(_ accounts: [GitHubAccount]) -> [GitHubAccount] {
        accounts.sorted {
            $0.login.localizedCaseInsensitiveCompare($1.login) == .orderedAscending
        }
    }

    public static func linkSSH(login: String, keyPath: String, alias: String?) throws {
        let accounts = try GHClient.live.accounts()
        guard accounts.contains(where: { $0.login == login }) else {
            throw SSHManagerError.message("GitHub account '\(login)' is not authenticated in gh.")
        }
        try SSHManager.live.setup()
        try SSHManager.live.link(login: login, keyPath: keyPath, alias: alias)
    }

    public static func unlinkSSH(login: String) throws {
        try SSHManager.live.unlink(login: login)
    }

    public static func authenticateAccount() throws {
        try GHClient.live.authenticateAccount()
    }

    public static func makeAuthentication() -> GHAuthentication {
        GHAuthentication.live
    }

    public static func switchAccount(to login: String) throws {
        try switchAccount(to: login, ghClient: .live, sshManager: .live, gitConfig: .live)
    }

    static func switchAccount(
        to login: String,
        ghClient: GHClient,
        sshManager: SSHManager,
        gitConfig: GitConfigClient
    ) throws {
        guard let previousLogin = try ghClient.accounts().first(where: \.active)?.login else {
            throw AccountSwitchError.noActiveGitHubAccount
        }
        let previousGitIdentity = try gitConfig.globalIdentity()
        let previous = try sshManager.activate(login: login)
        var didSwitchGitHub = false
        var didStartGitIdentityUpdate = false
        do {
            try ghClient.switchAccount(to: login)
            didSwitchGitHub = true
            let identity = try ghClient.gitIdentity()
            didStartGitIdentityUpdate = true
            try gitConfig.setGlobalIdentity(identity)
        } catch {
            var rollbackErrors: [String] = []

            if didStartGitIdentityUpdate {
                recordRollbackError(in: &rollbackErrors) {
                    try gitConfig.restoreGlobalIdentity(previousGitIdentity)
                }
            }
            if didSwitchGitHub, previousLogin != login {
                recordRollbackError(in: &rollbackErrors) {
                    try ghClient.switchAccount(to: previousLogin)
                }
            }
            recordRollbackError(in: &rollbackErrors) {
                try sshManager.restoreManagedConfig(previous)
            }

            guard rollbackErrors.isEmpty else {
                throw AccountSwitchError.rollbackFailed(
                    original: error.localizedDescription,
                    rollback: rollbackErrors
                )
            }
            throw error
        }
    }

    private static func recordRollbackError(
        in errors: inout [String],
        operation: () throws -> Void
    ) {
        do {
            try operation()
        } catch {
            errors.append(error.localizedDescription)
        }
    }
}

private enum AccountSwitchError: LocalizedError {
    case noActiveGitHubAccount
    case rollbackFailed(original: String, rollback: [String])

    var errorDescription: String? {
        switch self {
        case .noActiveGitHubAccount:
            "No active GitHub account to restore if switching fails."
        case let .rollbackFailed(original, rollback):
            "\(original) Rollback also failed: \(rollback.joined(separator: "; "))"
        }
    }
}
