// swift-tools-version: 6.0
import PackageDescription

// TODO: llama.cpp SPM integration
//
// When the llama.cpp Swift Package is ready, add:
//
//   dependencies: [
//       .package(url: "https://github.com/ggerganov/llama.cpp.git", from: "b5400")
//   ]
//
// And add "llama" to the TradePilot target's dependencies array, then replace
// MockLlamaEngine in LlamaProvider.swift with the real LlamaCppEngine.
//
// Note: llama.cpp does not yet publish tagged SPM releases. Track progress at:
// https://github.com/ggerganov/llama.cpp/issues/1803

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
            path: "Sources/TradePilot"
        ),
        .testTarget(
            name: "TradePilotTests",
            dependencies: ["TradePilot"],
            path: "Tests/TradePilotTests"
        )
    ]
)
