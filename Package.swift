// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "github-account-switcher",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "gas", targets: ["gas"]),
    ],
    targets: [
        .target(name: "GitHubAccountSwitcherCore"),
        .executableTarget(
            name: "gas",
            dependencies: ["GitHubAccountSwitcherCore"]
        ),
        .testTarget(
            name: "GitHubAccountSwitcherCoreTests",
            dependencies: ["GitHubAccountSwitcherCore"]
        ),
    ]
)
