// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Rashun",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Rashun",
            path: "Sources"
        ),
        .testTarget(
            name: "RashunTests",
            dependencies: ["Rashun"],
            path: "Tests"
        ),
    ]
)
