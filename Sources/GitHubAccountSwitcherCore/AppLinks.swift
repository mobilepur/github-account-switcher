import Foundation

public enum AppLinks {
    public static func releaseNotes(version: String) -> URL {
        URL(
            string: "https://github.com/mobilepur/github-account-switcher/releases/tag/v\(version)"
        )!
    }

    public static let newIssue = URL(
        string: "https://github.com/mobilepur/github-account-switcher/issues/new"
    )!
}
