// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "github-account-switcher",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "gh-switcher", targets: ["GitHubAccountSwitcherCLI"]),
    ],
    targets: [
        .target(name: "GitHubAccountSwitcherCore"),
        .executableTarget(
            name: "GitHubAccountSwitcherCLI",
            dependencies: ["GitHubAccountSwitcherCore"]
        ),
        .testTarget(
            name: "GitHubAccountSwitcherCoreTests",
            dependencies: ["GitHubAccountSwitcherCore"]
        ),
    ]
)
