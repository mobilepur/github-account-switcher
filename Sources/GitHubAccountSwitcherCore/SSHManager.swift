import Foundation

struct SSHMapping: Codable, Equatable, Sendable {
    let keyPath: String
    let alias: String?
}

struct SSHManager {
    let mappingsURL: URL
    let managedConfigURL: URL
    let userConfigURL: URL

    var backupConfigURL: URL {
        URL(fileURLWithPath: userConfigURL.path + ".gh-switcher.backup")
    }

    static var live: SSHManager {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let applicationSupport = home.appending(path: "Library/Application Support/GitHubAccountSwitcher")
        return SSHManager(
            mappingsURL: applicationSupport.appending(path: "ssh-mappings.json"),
            managedConfigURL: applicationSupport.appending(path: "ssh_config"),
            userConfigURL: home.appending(path: ".ssh/config")
        )
    }

    func mappings() throws -> [String: SSHMapping] {
        guard FileManager.default.fileExists(atPath: mappingsURL.path) else { return [:] }
        return try JSONDecoder().decode(
            [String: SSHMapping].self,
            from: Data(contentsOf: mappingsURL)
        )
    }

    func link(login: String, keyPath: String, alias: String?) throws {
        let expandedPath = NSString(string: keyPath).expandingTildeInPath
        guard !expandedPath.hasSuffix(".pub") else {
            throw SSHManagerError.message("Select the private SSH key, not the .pub file.")
        }
        guard !expandedPath.contains(where: { $0 == "\n" || $0 == "\r" || $0 == "\"" }) else {
            throw SSHManagerError.message("SSH key path contains unsupported characters.")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw SSHManagerError.message("SSH key does not exist or is not a file.")
        }

        var values = try mappings()
        values[login] = SSHMapping(keyPath: expandedPath, alias: alias)
        try save(values)
    }

    func unlink(login: String) throws {
        var values = try mappings()
        guard values.removeValue(forKey: login) != nil else {
            throw SSHManagerError.message("No SSH key is linked for \(login).")
        }
        try save(values)
    }

    func setup() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: userConfigURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: managedConfigURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !fileManager.fileExists(atPath: managedConfigURL.path) {
            try Data().write(to: managedConfigURL, options: .atomic)
        }

        let include = "Include \"\(managedConfigURL.path)\""
        let existing = fileManager.fileExists(atPath: userConfigURL.path)
            ? try String(contentsOf: userConfigURL, encoding: .utf8)
            : ""
        guard !existing.components(separatedBy: .newlines).contains(include) else { return }

        if fileManager.fileExists(atPath: userConfigURL.path),
           !fileManager.fileExists(atPath: backupConfigURL.path) {
            try fileManager.copyItem(at: userConfigURL, to: backupConfigURL)
        }

        let separator = existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n"
        try "\(include)\n\(existing)\(separator)".write(
            to: userConfigURL,
            atomically: true,
            encoding: .utf8
        )
    }

    func activate(login: String) throws -> Data? {
        guard let mapping = try mappings()[login] else {
            throw SSHManagerError.message("No SSH key is linked for \(login).")
        }
        let previous = FileManager.default.fileExists(atPath: managedConfigURL.path)
            ? try Data(contentsOf: managedConfigURL)
            : nil
        let config = """
        # Managed by gh-switcher. Changes will be replaced.
        Host github.com
          HostName github.com
          User git
          IdentityFile "\(mapping.keyPath)"
          IdentitiesOnly yes

        """
        try FileManager.default.createDirectory(
            at: managedConfigURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try config.write(to: managedConfigURL, atomically: true, encoding: .utf8)
        return previous
    }

    func restoreManagedConfig(_ data: Data?) throws {
        if let data {
            try data.write(to: managedConfigURL, options: .atomic)
        } else if FileManager.default.fileExists(atPath: managedConfigURL.path) {
            try FileManager.default.removeItem(at: managedConfigURL)
        }
    }

    private func save(_ mappings: [String: SSHMapping]) throws {
        try FileManager.default.createDirectory(
            at: mappingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(mappings).write(to: mappingsURL, options: .atomic)
    }
}

enum SSHManagerError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(message): message
        }
    }
}
