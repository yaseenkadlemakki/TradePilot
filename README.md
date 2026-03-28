# TradePilot

![Python](https://img.shields.io/badge/python-3.11%2B-blue)
![FastAPI](https://img.shields.io/badge/FastAPI-0.100%2B-009688)
![License](https://img.shields.io/badge/license-MIT-green)
![Tests](https://img.shields.io/badge/tests-67%20passing-brightgreen)

**TradePilot** is an open-source options recommendation engine. It produces exactly **4 daily trade ideas** — one Long Call, one Long Put, one Short Call, and one Short Put — by running market data, sentiment analysis, and options flow through a 5-agent AI pipeline.

The backend can be self-hosted, or the entire pipeline can run on-device via the **TradePilot iOS app** (coming soon). All API keys are yours — TradePilot never proxies your data.

---

## How It Works

Five specialized agents run sequentially, each feeding its output to the next:

```
DataAggregator → SentimentIntelligence → QuantStrategy → RiskCompliance → ExpertAdvisor
      │                    │                   │               │                │
  50 tickers        Sentiment Report    4 Trade Proposals  Validated      4 Final Picks
```

1. **DataAggregator** — Collects market prices, options flow, Reddit posts, and news articles from 4 ingestors. Extracts tickers, computes 15-feature vectors, and surfaces the top 50 candidates. *(timeout: 180 min)*
2. **SentimentIntelligence** — Scores each candidate on sentiment, momentum, conviction, and source diversity using a keyword-based scorer with optional Claude LLM deep analysis for the top 25. *(timeout: 15 min)*
3. **QuantStrategy** — Selects the best candidate per strategy type, calculates Greeks and risk/reward, and emits exactly 4 `TradeProposal` objects with composite scoring. *(timeout: 10 min)*
4. **RiskCompliance** — Validates proposals against hard limits (volume, open interest, bid-ask spread, IV, pump detection) and flags soft warnings. Rejected slots loop back to QuantStrategy for replacement (up to 3 retries). *(timeout: 10 min)*
5. **ExpertAdvisor** — Final coherence review: detects market regime, checks sector concentration, refines rationales, and produces the `DailyRecommendations` payload. *(timeout: 5 min)*

---

## BYO Keys

TradePilot follows a **Bring Your Own Keys** model. You supply API credentials for the data sources you want; the pipeline degrades gracefully for any that are absent.

| Variable | Provider | What it unlocks |
|---|---|---|
| `POLYGON_API_KEY` | [Polygon.io](https://polygon.io) | Market prices, options chains, Greeks, IV |
| `UNUSUAL_WHALES_API_KEY` | [Unusual Whales](https://unusualwhales.com) | Unusual flow, sweeps, premium |
| `REDDIT_CLIENT_ID` + `REDDIT_CLIENT_SECRET` | [Reddit API](https://www.reddit.com/prefs/apps) | r/wallstreetbets, r/options, r/stocks, r/investing |
| `NEWS_API_KEY` | [NewsAPI](https://newsapi.org) | Financial headlines and full-text articles |
| `ANTHROPIC_API_KEY` | [Anthropic](https://console.anthropic.com) | Optional — LLM deep analysis; keyword scorer works without it |

Optional infrastructure (in-memory fallbacks used locally):

```bash
TIMESCALE_URL=postgresql+asyncpg://tradepilot:password@localhost:5432/tradepilot
MONGO_URL=mongodb://localhost:27017
REDIS_URL=redis://localhost:6379/0
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
JWT_SECRET=change-me-to-a-long-random-string
```

---

## Installation & Setup

### Prerequisites

- Python 3.11+
- API keys for the data sources you want (see [BYO Keys](#byo-keys) above)

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/yaseenkadlemakki/TradePilot.git
cd TradePilot/tradepilot-backend

# 2. Create and activate a virtual environment
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure environment variables
cp ../.env.example .env
# Edit .env and fill in your API keys
```

### Start the API server

```bash
cd tradepilot-backend
python -m api.main
```

The server starts on `http://localhost:8000`.

### Run tests

```bash
# From the repo root
source .venv/bin/activate
python -m pytest tests/ -v
```

---

## API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Health check with version and timestamp |
| `/health/ready` | GET | Readiness probe |
| `/api/v1/recommendations/today` | GET | Today's 4 recommendations |
| `/api/v1/recommendations/{date}` | GET | Recommendations by date (YYYY-MM-DD) |
| `/api/v1/recommendations/detail/{id}` | GET | Full details for a single recommendation |
| `/api/v1/recommendations/history` | GET | Historical recommendations (1–90 days, optional strategy filter) |
| `/api/v1/recommendations/performance` | GET | Aggregate performance metrics |
| `/api/v1/recommendations/trigger` | POST | Manually trigger the pipeline |

---

## Data Sources

| Source | Provider | Priority | What it feeds |
|---|---|---|---|
| Market prices + options chains | Polygon.io | 1 (highest) | OHLCV bars, Greeks, IV, bid/ask |
| Unusual options activity | Unusual Whales | 2 | Premium, sentiment, sweep detection |
| News articles | NewsAPI | 2 | Headlines + full text for NLP |
| Reddit posts | Reddit API | 3 | r/wallstreetbets, r/options, r/stocks, r/investing |

---

## Tech Stack

| Layer | Technologies |
|---|---|
| **Runtime** | Python 3.11+, FastAPI, Pydantic v2, uvicorn |
| **AI / ML** | Anthropic Claude API (optional), FinBERT (scaffolded), scikit-learn, NumPy, pandas |
| **Logging** | structlog (structured JSON logging) |
| **Data Sources** | Polygon.io, Unusual Whales, Reddit API, NewsAPI |
| **Storage** | TimescaleDB (asyncpg), MongoDB (motor), Redis (hiredis) |
| **Streaming** | Kafka (aiokafka) |
| **Testing** | pytest, pytest-asyncio, pytest-cov, pytest-mock |

---

## Project Structure

```
TradePilot/
├── tradepilot-backend/
│   ├── agents/              # 5 AI agents + DAG orchestrator
│   │   ├── base.py          # BaseAgent[InputT, OutputT] with timeout + AgentError
│   │   ├── data_aggregator.py
│   │   ├── sentiment_intelligence.py
│   │   ├── quant_strategy.py
│   │   ├── risk_compliance.py
│   │   ├── expert_advisor.py
│   │   └── orchestrator.py
│   ├── api/
│   │   ├── main.py          # FastAPI app with CORS + lifespan
│   │   ├── routes/          # health.py, recommendations.py
│   │   └── schemas/         # recommendation.py — all Pydantic models
│   ├── config/
│   │   ├── settings.py      # Pydantic Settings (env-driven)
│   │   └── constants.py     # Enums, scoring weights, risk thresholds
│   ├── data_pipelines/
│   │   ├── ingestors/       # BaseIngestor + market_data, options_flow, reddit_scraper, news_feed
│   │   └── processors/      # ticker_extractor, sentiment_scorer, feature_engineer
│   ├── models/              # pump_detector (implemented), FinBERT + strategy (scaffolded)
│   └── services/            # recommendation_service.py — business logic layer
├── tests/
│   ├── unit/                # 56 tests across 5 files
│   ├── integration/         # 11 tests across 2 files
│   └── conftest.py
└── .env.example
```

---

## Current Status

The core pipeline (QuantStrategy + Orchestrator), API layer, and all processors are fully implemented. Several components are scaffolded for production:

| Component | Status |
|---|---|
| QuantStrategyAgent | Implemented — generates 4 proposals per run |
| PipelineOrchestrator | Implemented — wires agents, measures duration |
| TickerExtractor, SentimentScorer, FeatureEngineer | Implemented |
| PumpDetector | Implemented (rule-based) |
| DataAggregatorAgent | Scaffolded — ingestors not yet wired |
| SentimentIntelligenceAgent | Scaffolded — LLM integration pending |
| RiskComplianceAgent | Scaffolded — validation logic pending |
| ExpertAdvisorAgent | Scaffolded — coherence review pending |
| Ingestors (Polygon, Unusual Whales, Reddit, NewsAPI) | Scaffolded — API clients pending |
| Storage | In-memory; production config points to TimescaleDB + MongoDB |
| Caching | Redis configured but not yet wired |
| Streaming | Kafka topics defined; event bus not yet active |
| FinBERT | Placeholder directory; using keyword scorer |

---

## Roadmap

- [ ] Wire Polygon.io, Unusual Whales, Reddit, and NewsAPI ingestors
- [ ] Implement full DataAggregator pipeline
- [ ] Integrate FinBERT for sentence-level sentiment
- [ ] Complete RiskCompliance validation and retry loop
- [ ] ExpertAdvisor with Claude LLM coherence review
- [ ] Persistent storage (TimescaleDB + MongoDB)
- [ ] **TradePilot iOS app** — on-device pipeline with local inference, zero-server deployment, BYO keys stored in iOS Keychain

---

## Contributing

Contributions are welcome. To get started:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and add tests
4. Ensure all tests pass: `python -m pytest tests/ -v`
5. Open a pull request with a clear description of what you changed and why

Please keep pull requests focused — one feature or fix per PR.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Disclaimer

**This is not financial advice.** Options trading involves substantial risk of loss and is not appropriate for all investors. Past performance does not guarantee future results. Use this software for educational and research purposes only.
