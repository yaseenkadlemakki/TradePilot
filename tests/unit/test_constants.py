"""Unit tests for config/constants — 7 tests."""

from __future__ import annotations

from config.constants import (
    BEARISH_KEYWORDS,
    BULLISH_KEYWORDS,
    COMMON_WORDS,
    DataSource,
    MarketRegime,
    StrategyType,
)


# 1
def test_strategy_type_has_four_values() -> None:
    assert len(list(StrategyType)) == 4


# 2
def test_strategy_type_values_are_strings() -> None:
    for st in StrategyType:
        assert isinstance(st.value, str)


# 3
def test_data_source_includes_polygon() -> None:
    assert DataSource.POLYGON.value == "polygon"


# 4
def test_market_regime_has_four_regimes() -> None:
    assert len(list(MarketRegime)) == 4


# 5
def test_common_words_contains_typical_filter_words() -> None:
    assert "THE" in COMMON_WORDS
    assert "BUY" in COMMON_WORDS
    assert "CEO" in COMMON_WORDS


# 6
def test_bullish_keywords_non_empty() -> None:
    assert len(BULLISH_KEYWORDS) > 0
    assert "bullish" in BULLISH_KEYWORDS


# 7
def test_bearish_keywords_non_empty() -> None:
    assert len(BEARISH_KEYWORDS) > 0
    assert "bearish" in BEARISH_KEYWORDS
