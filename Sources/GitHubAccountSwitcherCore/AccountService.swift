import Foundation

public struct GitHubAccount: Identifiable, Sendable {
    public let login: String
    public let isActive: Bool
    public let sshKeyPath: String?
    public let alias: String?

    public var id: String { login }
    public var displayName: String { alias ?? login }
    public var isConfigured: Bool { sshKeyPath != nil }
    public var menuBarAbbreviation: String {
        String(displayName.prefix(3)).lowercased()
    }
}

public enum AccountService {
    public static func accounts() throws -> [GitHubAccount] {
        let mappings = try SSHManager.live.mappings()
        return try GHClient.live.accounts().map { account in
            let mapping = mappings[account.login]
            return GitHubAccount(
                login: account.login,
                isActive: account.active,
                sshKeyPath: mapping?.keyPath,
                alias: mapping?.alias
            )
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

    public static func switchAccount(to login: String) throws {
        try switchAccount(to: login, ghClient: .live, sshManager: .live)
    }

    static func switchAccount(to login: String, ghClient: GHClient, sshManager: SSHManager) throws {
        let previous = try sshManager.activate(login: login)
        do {
            try ghClient.switchAccount(to: login)
        } catch {
            try sshManager.restoreManagedConfig(previous)
            throw error
        }
    }
}
