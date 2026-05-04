// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RunBar",
    defaultLocalization: "fr",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RunBar", targets: ["RunBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "RunBar",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/RunBar",
            exclude: ["App/Secrets.template.swift.txt"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "RunBarTests",
            dependencies: ["RunBar"],
            path: "Tests/RunBarTests"
        )
    ]
)
