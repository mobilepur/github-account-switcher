import Foundation

struct Account: Codable, Equatable, Sendable {
    let keyPath: String
    let alias: String?

    var displayName: String {
        alias ?? URL(fileURLWithPath: keyPath).lastPathComponent
    }
}

struct Configuration: Codable, Equatable, Sendable {
    var accounts: [Account] = []
    var activeKeyPath: String?
}

struct AccountStore {
    let configurationURL: URL

    func load() throws -> Configuration {
        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            return Configuration()
        }

        let data = try Data(contentsOf: configurationURL)
        if let configuration = try? JSONDecoder().decode(Configuration.self, from: data) {
            return configuration
        }

        return Configuration(accounts: try JSONDecoder().decode([Account].self, from: data))
    }

    func save(_ configuration: Configuration) throws {
        try FileManager.default.createDirectory(
            at: configurationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(configuration)
        try data.write(to: configurationURL, options: .atomic)
    }
}
