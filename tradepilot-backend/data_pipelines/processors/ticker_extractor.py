from __future__ import annotations

import re

from config.constants import COMMON_WORDS


class TickerExtractor:
    """Extract stock ticker symbols from free-form text."""

    # Matches bare uppercase tokens 1-5 chars (word boundaries)
    _BARE_PATTERN: re.Pattern[str] = re.compile(r"(?<!\$)\b([A-Z]{1,5})\b")
    # Matches $TICKER cashtag notation
    _CASH_PATTERN: re.Pattern[str] = re.compile(r"\$([A-Z]{1,5})\b")

    def __init__(self, common_words: frozenset[str] | None = None) -> None:
        self._common_words: frozenset[str] = common_words if common_words is not None else COMMON_WORDS

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def extract(self, text: str) -> list[str]:
        """Return deduplicated tickers found in *text*, cashtags first."""
        if not text:
            return []

        cashtags = self._CASH_PATTERN.findall(text)
        bare = self._BARE_PATTERN.findall(text)

        tokens = self.filter_common_words(cashtags + bare)
        return self._deduplicate(tokens)

    def filter_common_words(self, tickers: list[str]) -> list[str]:
        """Remove tokens that are common English words or non-ticker abbreviations."""
        return [t for t in tickers if t not in self._common_words]

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _deduplicate(tokens: list[str]) -> list[str]:
        seen: set[str] = set()
        result: list[str] = []
        for t in tokens:
            if t not in seen:
                seen.add(t)
                result.append(t)
        return result
