# TradePilot

AI-powered stock options recommendation engine that produces exactly **4 daily trades** -- one Long Call, one Long Put, one Short Call, and one Sell Put -- by running market data, sentiment, and options flow through a 5-agent pipeline.

## How It Works

Five specialized agents run sequentially, each feeding its output to the next:

```
DataAggregator -> SentimentIntelligence -> QuantStrategy -> RiskCompliance -> ExpertAdvisor
      |                     |                    |               |               |
  50 tickers       Sentiment Report      4 Trade Proposals  Validated      4 Final Picks
```

1. **DataAggregator** -- Collects market prices, options flow, Reddit posts, and news articles from 4 ingestors. Extracts tickers, computes 15-feature vectors, and surfaces the top 50 candidates. *(timeout: 180 min)*
2. **SentimentIntelligence** -- Scores each candidate on sentiment, momentum, conviction, and source diversity using a keyword-based scorer with optional Claude LLM deep analysis for the top 25. *(timeout: 15 min)*
3. **QuantStrategy** -- Selects the best candidate per strategy type, calculates Greeks and risk/reward, and emits exactly 4 `TradeProposal` objects with composite scoring. *(timeout: 10 min)*
4. **RiskCompliance** -- Validates proposals against hard limits (volume, open interest, bid-ask spread, IV, pump detection) and flags soft warnings. Rejected slots loop back to QuantStrategy for replacement (up to 3 retries). *(timeout: 10 min)*
5. **ExpertAdvisor** -- Final coherence review: detects market regime, checks sector concentration, refines rationales, and produces the `DailyRecommendations` payload. *(timeout: 5 min)*

## Quick Start

```bash
# Clone and install
cd tradepilot-backend
pip install -r requirements.txt

# Configure
cp ../.env.example .env
# Edit .env with your API keys (see below)

# Run the API server
python -m api.main

# Run tests (67 tests: 56 unit + 11 integration)
cd .. && python -m pytest tests/ -v
```

## API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Health check with version and timestamp |
| `/health/ready` | GET | Readiness probe |
| `/api/v1/recommendations/today` | GET | Today's 4 recommendations |
| `/api/v1/recommendations/{date}` | GET | Recommendations by date (YYYY-MM-DD) |
| `/api/v1/recommendations/detail/{id}` | GET | Full details for a single recommendation |
| `/api/v1/recommendations/history` | GET | Historical recommendations (1-90 days, optional strategy filter) |
| `/api/v1/recommendations/performance` | GET | Aggregate performance metrics |
| `/api/v1/recommendations/trigger` | POST | Manually trigger the pipeline |

## Data Sources

| Source | Provider | Tier | What It Feeds |
|---|---|---|---|
| Market prices + options chains | Polygon.io | 1 (highest) | OHLCV bars, Greeks, IV, bid/ask |
| Unusual options activity | Unusual Whales | 2 | Premium, sentiment, sweep detection |
| News articles | NewsAPI | 2 | Headlines + full-text for NLP |
| Reddit posts | Reddit API | 3 | r/wallstreetbets, r/options, r/stocks, r/investing |

## Project Structure

```
tradepilot-backend/
|-- agents/              # 5 AI agents + DAG orchestrator with retry loops
|   |-- base.py          # Generic BaseAgent[InputT, OutputT] with timeout
|   |-- data_aggregator.py
|   |-- sentiment_intelligence.py
|   |-- quant_strategy.py
|   |-- risk_compliance.py
|   |-- expert_advisor.py
|   +-- orchestrator.py
|-- api/
|   |-- main.py          # FastAPI app with CORS + lifespan
|   |-- routes/          # health.py, recommendations.py
|   +-- schemas/         # recommendation.py -- all Pydantic models
|-- config/
|   |-- settings.py      # Pydantic Settings (env-driven)
|   +-- constants.py     # Enums, scoring weights, risk thresholds
|-- data_pipelines/
|   |-- ingestors/       # market_data, options_flow, reddit_scraper, news_feed
|   +-- processors/      # ticker_extractor, sentiment_scorer, feature_engineer
|-- models/              # Placeholder dirs for FinBERT, pump_detector, strategy
+-- services/            # recommendation_service.py -- business logic layer
tests/
|-- unit/                # 56 tests across 5 files
|-- integration/         # 11 tests across 2 files
+-- conftest.py          # Shared fixtures (events, features, sentiment reports)
```

## Tech Stack

**Runtime:** Python 3.11+, FastAPI, Pydantic v2, uvicorn

**AI/ML:** Anthropic Claude API (deep sentiment + coherence review), HuggingFace Transformers + PyTorch (FinBERT -- scaffolded, not yet wired), scikit-learn, NumPy, pandas

**Data infrastructure (configured, in-memory fallbacks for local dev):** TimescaleDB (asyncpg), MongoDB (motor), Redis (hiredis), Kafka (aiokafka)

**Market data:** Polygon.io, Unusual Whales, Reddit API (PRAW-style via httpx), NewsAPI

**Scheduling:** APScheduler (daily pipeline trigger)

**Testing:** pytest, pytest-asyncio, pytest-cov, pytest-mock

## Required API Keys

See `.env.example` for the full list. At minimum you need:

- `POLYGON_API_KEY` -- market data and options chains
- `UNUSUAL_WHALES_API_KEY` -- options flow
- `REDDIT_CLIENT_ID` + `REDDIT_CLIENT_SECRET` -- Reddit sentiment
- `NEWS_API_KEY` -- news articles
- `ANTHROPIC_API_KEY` -- Claude LLM for deep analysis (optional; keyword scorer works without it)

## Current Status

This is a working backend with full agent orchestration, risk validation, and API serving. A few components are scaffolded for production but use development fallbacks locally:

- **Storage:** Recommendations are held in-memory. Production config points to TimescaleDB + MongoDB.
- **Caching:** Redis is configured but not yet wired in the service layer.
- **Streaming:** Kafka topics are defined in constants but the event bus is not active.
- **FinBERT:** Model directory exists as a placeholder. Sentiment currently runs through a keyword-based scorer.
- **StockTwits:** Defined as a data source enum but no ingestor is implemented yet.

## Disclaimer

This is not financial advice. Options trading involves substantial risk of loss. Past performance does not guarantee future results.
