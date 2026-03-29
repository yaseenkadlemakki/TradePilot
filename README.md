# TradePilot

AI-powered stock options recommendation engine that produces exactly **4 daily trades** — one Long Call, one Long Put, one Short Call, and one Sell Put — through a 5-agent pipeline running entirely on your iPhone.

**No account required. No backend. No API keys needed to get started.**

---

## How It Works

Five specialized agents run sequentially on-device, each feeding its output to the next:

```
DataAggregator → SentimentIntelligence → QuantStrategy → RiskCompliance → ExpertAdvisor
      │                    │                   │               │                │
  50 tickers        Sentiment Report    4 Trade Proposals  Validated      4 Final Picks
```

1. **DataAggregator** — Collects market data, options flow, Reddit posts, and news. Extracts tickers, computes feature vectors, and surfaces the top 50 candidates.
2. **SentimentIntelligence** — Scores each candidate on sentiment, momentum, and conviction using on-device ML (Core ML FinBERT) with optional cloud LLM for deep analysis.
3. **QuantStrategy** — Selects the best candidate per strategy type with composite scoring and Greeks estimation.
4. **RiskCompliance** — Validates proposals against hard limits (volume, open interest, bid-ask spread, IV, pump detection). Rejected slots loop back to QuantStrategy for replacement (up to 3 retries).
5. **ExpertAdvisor** — Final coherence review using on-device LLM (Apple Foundation Models / Llama) or optional BYO Claude API key.

---

## Getting Started

### Option 1: Download from App Store
Coming soon.

### Option 2: Build from Source

```bash
git clone https://github.com/yaseenkadlemakki/TradePilot.git
cd TradePilot/tradepilot-ios
swift build
swift test
```

Open `tradepilot-ios/` in Xcode to run on your device.

No `.env` files. No server setup. No API keys required.

---

## BYO API Keys (All Optional)

TradePilot works out of the box with **demo data and on-device ML**. Add your own keys in Settings to unlock real-time data:

| Key | Provider | What It Unlocks | Free Tier? |
|-----|----------|----------------|------------|
| Polygon.io | [polygon.io](https://polygon.io) | Real-time market data + options chains | Yes (delayed data, 5 calls/min) |
| Unusual Whales | [unusualwhales.com](https://unusualwhales.com) | Options flow intelligence | No (starts at $50/mo) |
| Reddit OAuth | [reddit.com/dev](https://www.reddit.com/prefs/apps) | Live Reddit sentiment | Yes (100 req/min) |
| NewsAPI | [newsapi.org](https://newsapi.org) | Financial news articles | Yes (100 requests/day) |
| Claude API | [anthropic.com](https://console.anthropic.com) | Enhanced AI analysis (Expert Advisor) | Pay per token |

**Without any keys:** Demo data + on-device models (Apple Foundation Models or rule-based fallback).

**With free-tier keys only:** Functional pipeline with delayed market data, Reddit sentiment, and news — no options flow.

**With all keys:** Full real-time pipeline.

All keys are stored securely in the iOS Keychain — never in plaintext.

---

## On-Device ML

| Component | Default (no setup) | With BYO Key |
|-----------|-------------------|--------------|
| Sentiment scoring | Core ML FinBERT (~50MB) | Same |
| Expert Advisor | Apple Foundation Models / Rule-based | Claude API |
| Deep analysis | Rule-based fallback | Claude API |

The app ships with everything it needs. No model downloads at runtime.

---

## Current Status

| Area | Status |
|------|--------|
| iOS app | Working — Dashboard, Detail, History, Settings, Onboarding |
| 5-agent pipeline | Working — full on-device execution |
| On-device ML | Working — Core ML FinBERT + Apple Foundation Models |
| BYO key management | Working — Keychain storage, per-key enable/disable |
| Demo data mode | Working — zero-key out-of-the-box experience |
| Background scheduling | Working — BGTaskScheduler, 6:00 AM ET pre-market |
| Local notifications | Working — push when recommendations are ready |
| App Store release | Planned |

---

## Features

- 4 daily trade recommendations: Long Call, Long Put, Short Call, Sell Put
- Multi-source data ingestion (market, options flow, Reddit, news)
- 5-agent AI pipeline with retry loops and risk validation
- Pump detection algorithm for coordinated manipulation
- On-device sentiment analysis (Core ML FinBERT)
- Background daily pipeline via BGTaskScheduler (6:00 AM ET pre-market)
- Local notifications when recommendations are ready
- Full offline support via SwiftData
- BYO API key management with Keychain storage
- Accessibility (VoiceOver, Dynamic Type)

---

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full system design.

---

## Self-Hosted Backend (Optional)

For power users who want to run the Python pipeline server locally:

```bash
cd tradepilot-backend
pip install -r requirements.txt
python -m api.main
```

The backend runs the same 5-agent pipeline but requires API keys configured in `.env`. See `.env.example` for the full list. The iOS app does not depend on this.

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/health/ready` | GET | Readiness probe |
| `/api/v1/recommendations/today` | GET | Today's 4 recommendations |
| `/api/v1/recommendations/{date}` | GET | Recommendations by date |
| `/api/v1/recommendations/history` | GET | Historical recommendations |
| `/api/v1/recommendations/performance` | GET | Performance metrics |
| `/api/v1/recommendations/trigger` | POST | Manually trigger pipeline |

---

## Testing

```bash
# iOS (Swift)
cd tradepilot-ios && swift test

# Backend (Python)
python -m pytest tests/ -v --cov
```

iOS: 73 tests across models, pipeline, networking, and integration.
Backend: 138 tests, 98.7% coverage.

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make changes and add tests
4. Ensure all tests pass
5. Open a pull request

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Disclaimer

**This is not financial advice.** Options trading involves substantial risk of loss and is not appropriate for all investors. Past performance does not guarantee future results. Use this software for educational and research purposes only.
