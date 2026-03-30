# TradePilot — System Architecture

## Overview

TradePilot is an iOS-first options recommendation engine. The entire 5-agent pipeline runs on-device with no backend required.

## Agent Pipeline

```
DataAggregator -> SentimentIntelligence -> QuantStrategy -> RiskCompliance -> ExpertAdvisor
```

1. **DataAggregator** — Collects market data, options flow, Reddit, news via BYO API keys
2. **SentimentIntelligence** — On-device sentiment scoring (Core ML FinBERT ready, keyword fallback)
3. **QuantStrategy** — Selects 4 trades (Long Call, Long Put, Short Call, Sell Put) with composite scoring
4. **RiskCompliance** — Validates against hard limits, pump detection
5. **ExpertAdvisor** — Portfolio coherence via on-device LLM (Llama 3.2 / Apple Foundation / Claude BYO / rule-based)

## LLM Provider Hierarchy

1. Llama 3.2 3B (on-device, ~2GB download)
2. Apple Foundation Models (iOS 26+)
3. Claude API (BYO key)
4. Rule-based fallback (always available)

## Data Flow

- API keys stored in iOS Keychain
- Recommendations cached in SwiftData
- Background pipeline via BGTaskScheduler (6AM ET daily)
- Local notifications on completion

## Backend (Optional)

Python FastAPI backend available for self-hosting. Same pipeline logic. See `tradepilot-backend/`.

## Testing

- Python: 67 tests, pytest + coverage
- Swift: Unit, functional, integration tests via XCTest

See [THIRD_PARTY_LICENSES.md](tradepilot-ios/THIRD_PARTY_LICENSES.md) for Llama 3.2 license attribution.
