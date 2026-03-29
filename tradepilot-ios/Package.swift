// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TradePilot",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "TradePilot", targets: ["TradePilot"])
    ],
    targets: [
        .target(
            name: "TradePilot",
            path: "Sources/TradePilot",
            exclude: ["App/TradePilotApp.swift"]
        ),
        .testTarget(
            name: "TradePilotTests",
            dependencies: ["TradePilot"],
            path: "Tests/TradePilotTests"
        )
    ]
)
