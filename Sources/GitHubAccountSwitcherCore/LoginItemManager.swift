import Foundation

public struct LoginItemManager: Sendable {
    private let plistURL: URL
    private let executablePath: String

    public static var live: LoginItemManager {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return LoginItemManager(
            plistURL: home.appending(path: "Library/LaunchAgents/com.mobilepur.github-account-switcher.plist"),
            executablePath: Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
        )
    }

    public init(plistURL: URL, executablePath: String) {
        self.plistURL = plistURL
        self.executablePath = executablePath
    }

    public var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let plist: [String: Any] = [
                "Label": "com.mobilepur.github-account-switcher",
                "ProgramArguments": [executablePath],
                "RunAtLoad": true,
                "EnvironmentVariables": [
                    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
                ],
            ]
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: plistURL, options: .atomic)
        } else if isEnabled {
            try FileManager.default.removeItem(at: plistURL)
        }
    }
}
