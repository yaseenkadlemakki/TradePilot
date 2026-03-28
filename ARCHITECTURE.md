# TradePilot — Architecture

## System Overview

TradePilot is a Python 3.11 options recommendation engine. It ingests market data, options flow, Reddit sentiment, and financial news; processes that data through a 5-agent AI pipeline; and produces exactly 4 daily trade proposals (one per options strategy type). The system is designed to run self-hosted or fully on-device via the TradePilot iOS app.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         TradePilot Backend                          │
│                                                                     │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│   │  FastAPI App │    │  5-Agent     │    │  Data Pipelines      │  │
│   │  (REST API)  │───▶│  Pipeline    │◀───│  (Ingestors +        │  │
│   └──────────────┘    └──────────────┘    │   Processors)        │  │
│          │                   │            └──────────────────────┘  │
│          ▼                   ▼                                       │
│   ┌──────────────┐    ┌──────────────┐                              │
│   │ Recommendation│   │  In-Memory   │                              │
│   │   Service    │◀──▶│    Store     │                              │
│   └──────────────┘    └──────────────┘                              │
└─────────────────────────────────────────────────────────────────────┘
```

**BYO Keys model** — all external API credentials (Polygon, Unusual Whales, Reddit, NewsAPI, Anthropic) are supplied by the operator via environment variables. TradePilot never proxies or stores these keys.

---

## Data Ingestion Pipeline

Four ingestors run in parallel during the DataAggregator stage. Each extends `BaseIngestor`, which provides structured logging (start/complete/error + record count) via `structlog`.

```
┌──────────────────────────────────────────────────────────────┐
│                     DataAggregator                           │
│                                                              │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐  │
│  │ MarketData   │  │  OptionsFlow  │  │    NewsFeed      │  │
│  │ (Polygon.io) │  │(Unusual Whales│  │   (NewsAPI)      │  │
│  └──────┬───────┘  └──────┬────────┘  └────────┬─────────┘  │
│         │                 │                    │             │
│         └─────────────────┴────────────────────┘             │
│                           │                                  │
│                  ┌────────▼────────┐  ┌──────────────────┐  │
│                  │ TickerExtractor │  │  RedditScraper   │  │
│                  │ SentimentScorer │  │  (Reddit API)    │  │
│                  │ FeatureEngineer │  └──────────────────┘  │
│                  └────────┬────────┘                         │
│                           │                                  │
│                  ┌────────▼────────┐                         │
│                  │   Top-50        │                         │
│                  │  Candidates     │                         │
│                  └─────────────────┘                         │
└──────────────────────────────────────────────────────────────┘
```

### Processors

| Processor | Purpose |
|---|---|
| `TickerExtractor` | Regex-based ticker extraction from free-form text; cashtag (`$AAPL`) and bare (`AAPL`) patterns; 70+ common-word filter |
| `SentimentScorer` | Keyword-based sentiment in [-1, 1]; conviction score in [0, 1]; batch scoring |
| `FeatureEngineer` | Computes `composite_score` from 4 weighted components (sentiment, momentum, options flow, technical); produces `CandidateFeatures` dataclass |

### CandidateFeatures

The canonical data structure passed between all pipeline stages:

```python
@dataclass
class CandidateFeatures:
    ticker: str
    price: float           # current price
    price_change_1d: float # 1-day return
    price_change_5d: float # 5-day return
    volume: float          # shares traded
    volume_ratio: float    # current / 20-day average
    iv: float              # implied volatility
    open_interest: int
    options_volume: int
    bid_ask_spread_pct: float
    sentiment_score: float # [-1, 1]
    mention_count: int
    source_diversity: int  # distinct data sources
    conviction: float      # [0, 1]
    delta: float
    gamma: float
    theta: float
    vega: float
    composite_score: float # weighted aggregate [0, 1]
    tags: list[str]
```

### Composite Score Weights

| Component | Weight | Formula |
|---|---|---|
| Sentiment | 0.30 | `(sentiment_score + 1.0) / 2.0` → [0, 1] |
| Momentum | 0.25 | `(price_change_1d + 0.20) / 0.40` → [0, 1] |
| Options Flow | 0.25 | `min(1.0, options_volume / 10_000)` |
| Technical | 0.20 | `min(1.0, volume_ratio / 10.0)` |

---

## 5-Agent Architecture

All agents extend `BaseAgent[InputT, OutputT]`, which provides:
- Async execution with configurable timeout
- Structured logging via `structlog` (start, complete, duration, error)
- `AgentError` wrapping for pipeline-level error propagation

```
DataAggregator
     │  list[CandidateFeatures] (top 50)
     ▼
SentimentIntelligence
     │  list[CandidateFeatures] (scored, top 25 deep-analysed)
     ▼
QuantStrategy
     │  list[TradeProposal] (exactly 4)
     ▼
RiskCompliance ──▶ (reject) ──▶ QuantStrategy (retry, max 3)
     │  list[ValidatedProposal]
     ▼
ExpertAdvisor
     │  DailyRecommendations
     ▼
  REST API / iOS app
```

### Agent Descriptions

| Agent | Timeout | Input | Output | Status |
|---|---|---|---|---|
| `DataAggregatorAgent` | 180 min | `AggregatorInput(tickers)` | `AggregatorOutput(candidates, metadata)` | Scaffolded |
| `SentimentIntelligenceAgent` | 15 min | `SentimentInput(candidates)` | `SentimentOutput(candidates, report)` | Scaffolded |
| `QuantStrategyAgent` | 10 min | `StrategyInput(candidates, run_date)` | `StrategyOutput(proposals)` | Implemented |
| `RiskComplianceAgent` | 10 min | `ComplianceInput(proposals)` | `ComplianceOutput(validated, rejected, warnings)` | Scaffolded |
| `ExpertAdvisorAgent` | 5 min | `AdvisorInput(proposals)` | `AdvisorOutput(recommendations, market_regime, metadata)` | Scaffolded |

### QuantStrategy Logic (Implemented)

For each of the 4 strategy types, selects a candidate from the sorted pool:

| Strategy | Selection | Strike multiplier |
|---|---|---|
| `LONG_CALL` | Highest composite score (bullish) | 1.05× current price |
| `SHORT_PUT` | Highest composite score (bullish) | 0.90× current price |
| `LONG_PUT` | Lowest composite score (bearish) | 0.95× current price |
| `SHORT_CALL` | Lowest composite score (bearish) | 1.10× current price |

Risk metrics per proposal:
- **Entry price**: `max(price × 0.02, $0.50)` (rough option premium)
- **Stop loss**: entry × 0.50
- **Take profit**: entry × 3.00
- **Expiry**: run date + 30 days

---

## Output Format Specification

The pipeline produces a `DailyRecommendations` payload (Pydantic model):

```json
{
  "run_date": "2026-03-28",
  "generated_at": "2026-03-28T14:00:00.000Z",
  "market_regime": "NEUTRAL",
  "pipeline_duration_seconds": 1.234,
  "recommendations": [
    {
      "proposal": {
        "ticker": "NVDA",
        "strategy_type": "LONG_CALL",
        "strike": 630.0,
        "expiry": "2026-04-27",
        "entry_price": 12.00,
        "stop_loss": 6.00,
        "take_profit": 36.00,
        "risk_reward_ratio": 3.0,
        "composite_score": 0.90,
        "greeks": {"delta": 0.0, "gamma": 0.0, "theta": 0.0, "vega": 0.0},
        "iv": 0.50,
        "volume": 5000,
        "open_interest": 15000,
        "rationale": "LONG_CALL on NVDA (score=0.900)"
      },
      "warnings": [],
      "passed": true
    }
  ],
  "metadata": {}
}
```

---

## Guardrails

### Hard Limits (RiskCompliance)

| Parameter | Threshold |
|---|---|
| Minimum options volume | 100 contracts |
| Minimum open interest | 500 contracts |
| Maximum bid-ask spread | 15% of mid-price |
| Maximum IV | 300% (3.0) |
| Pump detection score | ≥ 0.70 → reject |

### Pump Detection

`PumpDetector` uses a weighted combination of three signals:

| Signal | Weight | Formula |
|---|---|---|
| Volume ratio | 0.40 | `min(1, (volume_ratio - 1) / (threshold × 2 - 1))` |
| Price velocity | 0.30 | `min(1, abs(price_velocity) / (threshold × 2))` |
| Social momentum | 0.30 | `min(1, max(0, social_momentum))` |

Score ≥ 0.70 triggers rejection. Custom thresholds can be passed at construction.

### Retry Loop

When RiskCompliance rejects a proposal, the slot is sent back to QuantStrategy with the rejected ticker excluded. Maximum 3 retries per slot; if all retries fail, the slot is omitted from the final output.

---

## Testing Strategy

67 tests across unit and integration layers:

| Layer | Count | What's covered |
|---|---|---|
| Unit — TickerExtractor | 14 | Regex patterns, cashtags, deduplication, common-word filter |
| Unit — SentimentScorer | 14 | Polarity scoring, batch, conviction, edge cases |
| Unit — QuantStrategyAgent | 14 | 4 proposals, strategy selection, Greeks, expiry, ValueError on empty |
| Unit — PumpDetector | 14 | Score range, threshold, individual signal contributions |
| Integration — PipelineOrchestrator | 5 | Full pipeline output shape, run_date, duration, stub candidates |
| Integration — API endpoints | 6 | Health, readiness, today 404, trigger, version |

### Coverage Targets

- Minimum overall: 80%
- Excluded from coverage: config/settings.py, api/schemas, api/routes/recommendations.py, services/recommendation_service.py, ingestors (scaffolded), feature_engineer

### Running Tests

```bash
source .venv/bin/activate
python -m pytest tests/ -v --cov=tradepilot-backend --cov-report=term-missing
```

### Linting

```bash
ruff check tradepilot-backend/
```

Configuration: line-length=120, rules E/F/W/I.
