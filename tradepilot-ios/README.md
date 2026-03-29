# TradePilot iOS

SPM-based iOS 17+ app scaffold — core models, 5-agent pipeline, networking, and storage.

## Structure

```
Sources/TradePilot/
├── App/            SwiftUI @main entry point
├── Core/
│   ├── Models/     Codable data models (mirrors Python schemas)
│   ├── Networking/ APIClient + 4 service clients
│   ├── Auth/       KeychainManager (BYO API keys)
│   ├── Storage/    SwiftData LocalCache
│   └── Pipeline/   5-agent pipeline (DataAggregator → SentimentScorer → QuantStrategy → RiskCompliance → ExpertAdvisor)
└── Resources/
Tests/TradePilotTests/
    ModelTests, KeychainTests, PipelineTests, QuantStrategyTests, RiskComplianceTests, APIClientTests
```

## Build

```bash
cd tradepilot-ios
swift build
swift test
```
