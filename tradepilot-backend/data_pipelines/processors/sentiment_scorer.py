from __future__ import annotations

from config.constants import BEARISH_KEYWORDS, BULLISH_KEYWORDS


class SentimentScorer:
    """Keyword-based sentiment scorer that returns scores in [-1, 1]."""

    def __init__(
        self,
        bullish_words: frozenset[str] | None = None,
        bearish_words: frozenset[str] | None = None,
    ) -> None:
        self._bullish: frozenset[str] = bullish_words if bullish_words is not None else BULLISH_KEYWORDS
        self._bearish: frozenset[str] = bearish_words if bearish_words is not None else BEARISH_KEYWORDS

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def score(self, text: str) -> float:
        """Score *text* sentiment in [-1.0, 1.0]; 0.0 for empty/neutral."""
        if not text:
            return 0.0

        words = self._tokenize(text)
        if not words:
            return 0.0

        bull_hits = sum(1 for w in words if w in self._bullish)
        bear_hits = sum(1 for w in words if w in self._bearish)

        total = bull_hits + bear_hits
        if total == 0:
            return 0.0

        raw = (bull_hits - bear_hits) / total
        return round(max(-1.0, min(1.0, raw)), 6)

    def score_batch(self, texts: list[str]) -> list[float]:
        """Score multiple texts; returns list of same length."""
        return [self.score(t) for t in texts]

    def conviction_score(self, text: str) -> float:
        """How strongly opinionated is the text?  Returns [0, 1]."""
        if not text:
            return 0.0

        words = self._tokenize(text)
        if not words:
            return 0.0

        hits = sum(1 for w in words if w in self._bullish or w in self._bearish)
        return round(min(1.0, hits / max(len(words), 1)), 6)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _tokenize(text: str) -> list[str]:
        return text.lower().split()
