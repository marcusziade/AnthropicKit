// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmartAssistant",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/marcusziade/AnthropicKit.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SmartAssistant",
            dependencies: ["AnthropicKit"])
    ]
)

