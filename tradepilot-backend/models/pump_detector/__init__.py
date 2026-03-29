"""Pump-and-dump detection model."""

from __future__ import annotations

from config.constants import (
    PRICE_VELOCITY_THRESHOLD,
    PUMP_DETECTION_THRESHOLD,
    PUMP_PRICE_WEIGHT,
    PUMP_SOCIAL_WEIGHT,
    PUMP_VOLUME_WEIGHT,
    VOLUME_RATIO_THRESHOLD,
)


class PumpDetector:
    """Rule-based pump-and-dump detector.

    Computes a pump score in [0, 1] from three normalised sub-scores:
      - volume_score  — how far above average the current volume is
      - price_score   — how fast the price has moved recently
      - social_score  — how elevated social-media mentions are
    """

    def __init__(
        self,
        threshold: float = PUMP_DETECTION_THRESHOLD,
        volume_weight: float = PUMP_VOLUME_WEIGHT,
        price_weight: float = PUMP_PRICE_WEIGHT,
        social_weight: float = PUMP_SOCIAL_WEIGHT,
    ) -> None:
        self.threshold = threshold
        self._volume_weight = volume_weight
        self._price_weight = price_weight
        self._social_weight = social_weight

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def score(self, features: dict[str, float]) -> float:
        """Return pump probability in [0, 1]."""
        volume_score = self._volume_sub_score(features.get("volume_ratio", 1.0))
        price_score = self._price_sub_score(features.get("price_velocity", 0.0))
        social_score = self._social_sub_score(features.get("social_momentum", 0.0))

        combined = (
            self._volume_weight * volume_score
            + self._price_weight * price_score
            + self._social_weight * social_score
        )
        return round(min(1.0, max(0.0, combined)), 6)

    def detect(self, features: dict[str, float]) -> bool:
        """Return True if pump score exceeds threshold."""
        return self.score(features) >= self.threshold

    # ------------------------------------------------------------------
    # Sub-score helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _volume_sub_score(volume_ratio: float) -> float:
        """Map volume_ratio to [0, 1]; saturates at 10x average volume."""
        return min(1.0, max(0.0, (volume_ratio - 1.0) / (VOLUME_RATIO_THRESHOLD * 2.0 - 1.0)))

    @staticmethod
    def _price_sub_score(price_velocity: float) -> float:
        """Map absolute price change to [0, 1]; saturates at 2x threshold."""
        return min(1.0, max(0.0, abs(price_velocity) / (PRICE_VELOCITY_THRESHOLD * 2.0)))

    @staticmethod
    def _social_sub_score(social_momentum: float) -> float:
        """Social momentum is already in [0, 1]."""
        return min(1.0, max(0.0, social_momentum))
