// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "github-account-switcher",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "gh-switcher", targets: ["GitHubAccountSwitcherCLI"]),
        .executable(name: "gh-switcher-menubar", targets: ["GitHubAccountSwitcherMenuBar"]),
    ],
    targets: [
        .target(name: "GitHubAccountSwitcherCore"),
        .executableTarget(
            name: "GitHubAccountSwitcherCLI",
            dependencies: ["GitHubAccountSwitcherCore"]
        ),
        .executableTarget(
            name: "GitHubAccountSwitcherMenuBar",
            dependencies: ["GitHubAccountSwitcherCore"]
        ),
        .testTarget(
            name: "GitHubAccountSwitcherCoreTests",
            dependencies: ["GitHubAccountSwitcherCore"]
        ),
    ]
)
