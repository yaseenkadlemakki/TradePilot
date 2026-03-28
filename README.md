# TradePilot

![Python](https://img.shields.io/badge/python-3.11%2B-blue)
![FastAPI](https://img.shields.io/badge/FastAPI-0.100%2B-009688)
![License](https://img.shields.io/badge/license-MIT-green)
![Tests](https://img.shields.io/badge/tests-67%20passing-brightgreen)

AI-powered stock options recommendation engine that produces exactly **4 daily trades** — one Long Call, one Long Put, one Short Call, and one Short Put — by running market data, sentiment analysis, and options flow through a 5-agent pipeline.

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

## Features

- **4 daily trade recommendations** across Long Call, Long Put, Short Call, and Short Put strategies
- **Multi-source data ingestion** — market prices, unusual options flow, Reddit sentiment, and financial news
- **5-agent AI pipeline** with sequential data passing and automatic retry loops
- **Risk validation** with hard limits on volume, open interest, bid-ask spread, IV, and pump detection
- **Claude LLM integration** for deep sentiment analysis and final coherence review
- **REST API** with full history, performance metrics, and manual pipeline trigger
- **Scheduled execution** via APScheduler for daily automated runs
- **67 tests** — 56 unit + 11 integration

---

## Tech Stack

| Layer | Technologies |
|---|---|
| **Runtime** | Python 3.11+, FastAPI, Pydantic v2, uvicorn |
| **AI / ML** | Anthropic Claude API, HuggingFace Transformers + PyTorch (FinBERT), scikit-learn, NumPy, pandas |
| **Data Sources** | Polygon.io, Unusual Whales, Reddit API, NewsAPI |
| **Storage** | TimescaleDB (asyncpg), MongoDB (motor), Redis (hiredis) |
| **Streaming** | Kafka (aiokafka) |
| **Scheduling** | APScheduler |
| **Testing** | pytest, pytest-asyncio, pytest-cov, pytest-mock |

---

## Installation & Setup

### Prerequisites

- Python 3.11+
- API keys for your desired data sources (see [Required API Keys](#required-api-keys))

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/yaseenkadlemakki/TradePilot.git
cd TradePilot/tradepilot-backend

# 2. Install dependencies
pip install -r requirements.txt

# 3. Configure environment variables
cp ../.env.example .env
# Open .env and fill in your API keys
```

### Required API Keys

See `.env.example` for the full list. At minimum you need:

| Variable | Provider | Required? |
|---|---|---|
| `POLYGON_API_KEY` | [Polygon.io](https://polygon.io) | Yes — market data & options chains |
| `UNUSUAL_WHALES_API_KEY` | [Unusual Whales](https://unusualwhales.com) | Yes — options flow |
| `REDDIT_CLIENT_ID` + `REDDIT_CLIENT_SECRET` | [Reddit API](https://www.reddit.com/prefs/apps) | Yes — Reddit sentiment |
| `NEWS_API_KEY` | [NewsAPI](https://newsapi.org) | Yes — news articles |
| `ANTHROPIC_API_KEY` | [Anthropic](https://console.anthropic.com) | Optional — keyword scorer works without it |

Optional infrastructure (in-memory fallbacks used locally):

```bash
TIMESCALE_URL=postgresql+asyncpg://tradepilot:password@localhost:5432/tradepilot
MONGO_URL=mongodb://localhost:27017
REDIS_URL=redis://localhost:6379/0
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
JWT_SECRET=change-me-to-a-long-random-string
```

---

## Usage

### Start the API server

```bash
cd tradepilot-backend
python -m api.main
```

The server starts on `http://localhost:8000`.

### Run tests

```bash
# From the repo root
python -m pytest tests/ -v
```

### API Endpoints

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

| Source | Provider | Priority | What It Feeds |
|---|---|---|---|
| Market prices + options chains | Polygon.io | 1 (highest) | OHLCV bars, Greeks, IV, bid/ask |
| Unusual options activity | Unusual Whales | 2 | Premium, sentiment, sweep detection |
| News articles | NewsAPI | 2 | Headlines + full text for NLP |
| Reddit posts | Reddit API | 3 | r/wallstreetbets, r/options, r/stocks, r/investing |

---

## Project Structure

```
TradePilot/
├── tradepilot-backend/
│   ├── agents/              # 5 AI agents + DAG orchestrator with retry loops
│   │   ├── base.py          # Generic BaseAgent[InputT, OutputT] with timeout
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
│   │   ├── ingestors/       # market_data, options_flow, reddit_scraper, news_feed
│   │   └── processors/      # ticker_extractor, sentiment_scorer, feature_engineer
│   ├── models/              # Placeholder dirs for FinBERT, pump_detector, strategy
│   └── services/            # recommendation_service.py — business logic layer
├── tests/
│   ├── unit/                # 56 tests across 5 files
│   ├── integration/         # 11 tests across 2 files
│   └── conftest.py          # Shared fixtures (events, features, sentiment reports)
└── .env.example
```

---

## Current Status

This is a working backend with full agent orchestration, risk validation, and API serving. A few components are scaffolded for production but use development fallbacks locally:

| Component | Status |
|---|---|
| Storage | Recommendations held in-memory; production config points to TimescaleDB + MongoDB |
| Caching | Redis configured but not yet wired in the service layer |
| Streaming | Kafka topics defined in constants; event bus not yet active |
| FinBERT | Model directory exists as placeholder; sentiment currently uses keyword-based scorer |
| StockTwits | Defined as a data source enum; no ingestor implemented yet |

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
