// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RunBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "RunBar", targets: ["RunBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "RunBar",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/RunBar",
            exclude: ["App/Secrets.template.swift.txt"]
        ),
        .testTarget(
            name: "RunBarTests",
            dependencies: ["RunBar"],
            path: "Tests/RunBarTests"
        )
    ]
)
