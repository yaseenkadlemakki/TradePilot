# TradePilot

AI-powered options recommendation engine that delivers 4 daily stock options trades (Long Call, Long Put, Short Call, Sell Put) by fusing retail sentiment, institutional signals, quantitative analysis, and options flow intelligence through a multi-agent architecture.

## Architecture

```
DataAggregator â SentimentIntelligence â QuantStrategy â RiskCompliance â ExpertAdvisor
     â                    â                    â               â               â
  50 tickers      Sentiment Report      4 Trade Proposals  Validated      4 Final Picks
```

**5-Agent Pipeline** runs daily at 06:00â09:45 ET with timeout handling, fallback paths, and replacement loops.

## Quick Start

```bash
# Clone and install
cd tradepilot-backend
pip install -r requirements.txt

# Configure
cp ../.env.example .env
# Edit .env with your API keys

# Run the API server
python -m api.main

# Run tests
cd .. && python -m pytest tests/ -v
```

## Project Structure

```
tradepilot-backend/
âââ agents/           # 5 AI agents + orchestrator
âââ api/              # FastAPI server + routes
âââ config/           # Settings + constants
âââ data_pipelines/   # Ingestors + processors
âââ models/           # ML model configs
âââ services/         # Business logic layer
tests/
âââ unit/             # 59 unit tests
âââ integration/      # 8 integration tests
```

## API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Health check |
| `/api/v1/recommendations/today` | GET | Today's 4 recommendations |
| `/api/v1/recommendations/{date}` | GET | Recommendations by date |
| `/api/v1/recommendations/performance` | GET | Historical performance metrics |
| `/api/v1/recommendations/trigger` | POST | Manually trigger the pipeline |

## Tech Stack

- **Backend**: Python, FastAPI, Pydantic
- **AI/ML**: FinBERT (sentiment), Claude API (deep analysis)
- **Data**: TimescaleDB, MongoDB, Redis, Kafka
- **Market Data**: Polygon.io, Unusual Whales
- **Sentiment**: Reddit API, NewsAPI, StockTwits

## Disclaimer

This is not financial advice. Options trading involves substantial risk of loss.
