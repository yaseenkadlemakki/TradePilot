"""Feature engineering utilities for ticker candidates."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class CandidateFeatures:
    """All features required to score and rank a single ticker candidate."""

    ticker: str
    # Price features
    price: float = 0.0
    price_change_1d: float = 0.0
    price_change_5d: float = 0.0
    volume: float = 0.0
    volume_ratio: float = 1.0       # current / 20-day average
    # Options features
    iv: float = 0.0                  # implied volatility (0-3+)
    open_interest: int = 0
    options_volume: int = 0
    bid_ask_spread_pct: float = 0.0
    # Sentiment features
    sentiment_score: float = 0.0    # [-1, 1]
    mention_count: int = 0
    source_diversity: int = 0       # number of distinct data sources
    conviction: float = 0.0         # [0, 1]
    # Greeks (placeholders populated by market-data ingestor)
    delta: float = 0.0
    gamma: float = 0.0
    theta: float = 0.0
    vega: float = 0.0
    # Composite score (filled by pipeline)
    composite_score: float = 0.0
    # Raw tags
    tags: list[str] = field(default_factory=list)


class FeatureEngineer:
    """Compute composite feature vectors for ticker candidates."""

    def __init__(
        self,
        sentiment_weight: float = 0.30,
        momentum_weight: float = 0.25,
        options_flow_weight: float = 0.25,
        technical_weight: float = 0.20,
    ) -> None:
        """Initialise the feature engineer with scoring component weights.

        Args:
            sentiment_weight: Weight applied to the sentiment sub-score (default 0.30).
            momentum_weight: Weight applied to the momentum sub-score (default 0.25).
            options_flow_weight: Weight applied to the options-flow sub-score (default 0.25).
            technical_weight: Weight applied to the technical sub-score (default 0.20).
        """
        self._w = {
            "sentiment": sentiment_weight,
            "momentum": momentum_weight,
            "options": options_flow_weight,
            "technical": technical_weight,
        }

    def compute_composite_score(self, f: CandidateFeatures) -> float:
        """Return a composite score in [0, 1] for a feature vector."""
        sentiment_component = (f.sentiment_score + 1.0) / 2.0  # map [-1,1] → [0,1]

        momentum_component = min(1.0, max(0.0, (f.price_change_1d + 0.20) / 0.40))

        options_component = min(1.0, f.options_volume / 10_000.0) if f.options_volume > 0 else 0.0

        technical_component = min(1.0, max(0.0, f.volume_ratio / 10.0))

        score = (
            self._w["sentiment"] * sentiment_component
            + self._w["momentum"] * momentum_component
            + self._w["options"] * options_component
            + self._w["technical"] * technical_component
        )
        return round(min(1.0, max(0.0, score)), 6)

    def enrich(self, features: CandidateFeatures) -> CandidateFeatures:
        """Compute and attach composite_score to *features* in place."""
        features.composite_score = self.compute_composite_score(features)
        return features
