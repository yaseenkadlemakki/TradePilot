"""Shared constants and enumerations used across the TradePilot codebase."""

from enum import Enum


class StrategyType(str, Enum):
    """Supported options strategy types for trade proposals."""

    LONG_CALL = "long_call"
    LONG_PUT = "long_put"
    SHORT_CALL = "short_call"
    SHORT_PUT = "short_put"


class DataSource(str, Enum):
    """Identifiers for external data providers ingested by the pipeline."""

    POLYGON = "polygon"
    UNUSUAL_WHALES = "unusual_whales"
    REDDIT = "reddit"
    NEWS = "news"
    STOCKTWITS = "stocktwits"


class MarketRegime(str, Enum):
    """Broad market-regime classification used to contextualise recommendations."""

    BULL = "bull"
    BEAR = "bear"
    NEUTRAL = "neutral"
    VOLATILE = "volatile"


# Composite scoring weights (must sum to 1.0)
SENTIMENT_WEIGHT: float = 0.30
MOMENTUM_WEIGHT: float = 0.25
OPTIONS_FLOW_WEIGHT: float = 0.25
TECHNICAL_WEIGHT: float = 0.20

# Risk thresholds
MIN_VOLUME: int = 100
MIN_OPEN_INTEREST: int = 500
MAX_BID_ASK_SPREAD_PCT: float = 0.15
MAX_IV: float = 3.0  # 300%
PUMP_DETECTION_THRESHOLD: float = 0.7

# Pipeline limits
TOP_CANDIDATES: int = 50
DEEP_ANALYSIS_CANDIDATES: int = 25
MAX_RETRY_ATTEMPTS: int = 3

# Pump detection feature weights
PUMP_VOLUME_WEIGHT: float = 0.40
PUMP_PRICE_WEIGHT: float = 0.30
PUMP_SOCIAL_WEIGHT: float = 0.30

# Pump detection thresholds
VOLUME_RATIO_THRESHOLD: float = 5.0       # 5x average volume
PRICE_VELOCITY_THRESHOLD: float = 0.15    # 15% price move
SOCIAL_MOMENTUM_THRESHOLD: float = 0.80   # 80th-percentile mention rate

# Common tokens that are NOT stock tickers
COMMON_WORDS: frozenset[str] = frozenset(
    {
        "A", "I", "AN", "AS", "AT", "BE", "BY", "DO", "GO", "IF", "IN", "IS",
        "IT", "NO", "OF", "ON", "OR", "SO", "TO", "UP", "US", "WE", "AM",
        "ARE", "THE", "AND", "BUT", "FOR", "NOT", "YOU", "ALL", "CAN", "HAS",
        "HER", "HIS", "HOW", "ITS", "OUR", "OUT", "WHO", "WHY", "WAS", "HAD",
        "HIM", "TOO", "TWO", "CEO", "IPO", "ETF", "USA", "NYSE", "NASDAQ",
        "SEC", "WSB", "ATH", "ATL", "EPS", "PE", "BUY", "SELL", "HOLD",
        "PUT", "CALL", "OTM", "ITM", "ATM", "DD", "YOLO", "FOMO", "FUD",
        "DRS", "LOL", "IMO", "TBH", "AKA", "AH", "PM", "TD", "RH",
        "WTF", "OMG", "NET", "NEW", "OLD", "BIG", "BAD", "GOOD", "VERY",
        "JUST", "LIKE", "ALSO", "THEN", "WHEN", "WITH", "FROM", "BEEN",
        "HAVE", "THIS", "THAT", "WHAT", "SOME", "THEY", "WILL", "BEEN",
    }
)

BULLISH_KEYWORDS: frozenset[str] = frozenset(
    {
        "bullish", "moon", "rocket", "surge", "rally", "beat", "strong",
        "growth", "uptrend", "catalyst", "breakout", "squeeze", "soar",
        "explode", "skyrocket", "upgrade", "outperform", "record", "gains",
        "profit", "positive", "pumping", "ripping", "flying",
    }
)

BEARISH_KEYWORDS: frozenset[str] = frozenset(
    {
        "bearish", "crash", "drop", "decline", "weak", "miss", "downtrend",
        "resistance", "dump", "fall", "plunge", "collapse", "downgrade",
        "underperform", "loss", "negative", "selloff", "sell-off", "tank",
        "bleeding", "sinking", "collapsing",
    }
)
