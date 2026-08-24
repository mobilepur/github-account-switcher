import Foundation

struct Account: Codable, Equatable, Sendable {
    let keyPath: String
    let alias: String?

    var displayName: String {
        alias ?? URL(fileURLWithPath: keyPath).lastPathComponent
    }
}

struct AccountStore {
    let configurationURL: URL

    func load() throws -> [Account] {
        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            return []
        }

        return try JSONDecoder().decode([Account].self, from: Data(contentsOf: configurationURL))
    }

    func save(_ accounts: [Account]) throws {
        try FileManager.default.createDirectory(
            at: configurationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(accounts)
        try data.write(to: configurationURL, options: .atomic)
    }
}
