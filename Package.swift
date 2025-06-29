// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnthropicKit",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "AnthropicKit",
            targets: ["AnthropicKit"]),
        .executable(
            name: "anthropic-cli",
            targets: ["AnthropicKitCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "AnthropicKit",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]),
        .executableTarget(
            name: "AnthropicKitCLI",
            dependencies: [
                "AnthropicKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(
            name: "AnthropicKitTests",
            dependencies: ["AnthropicKit"]),
        .testTarget(
            name: "AnthropicKitIntegrationTests",
            dependencies: ["AnthropicKit"])
    ]
)