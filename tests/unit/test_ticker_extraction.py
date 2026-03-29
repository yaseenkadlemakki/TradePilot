"""Unit tests for TickerExtractor — 14 tests."""

import pytest
from data_pipelines.processors.ticker_extractor import TickerExtractor


@pytest.fixture()
def extractor() -> TickerExtractor:
    return TickerExtractor()


# 1
def test_extract_single_known_ticker(extractor: TickerExtractor) -> None:
    result = extractor.extract("NVDA is up today")
    assert "NVDA" in result


# 2
def test_extract_multiple_tickers(extractor: TickerExtractor) -> None:
    result = extractor.extract("AAPL MSFT GOOG all rallying")
    assert "AAPL" in result
    assert "MSFT" in result
    assert "GOOG" in result


# 3
def test_extract_from_full_sentence(extractor: TickerExtractor) -> None:
    result = extractor.extract("I bought TSLA calls and sold AMZN puts")
    assert "TSLA" in result
    assert "AMZN" in result


# 4
def test_extract_empty_string_returns_empty(extractor: TickerExtractor) -> None:
    assert extractor.extract("") == []


# 5
def test_extract_no_tickers_in_lowercase_text(extractor: TickerExtractor) -> None:
    result = extractor.extract("this is all lowercase text with no tickers")
    assert result == []


# 6
def test_filter_common_words_removes_the(extractor: TickerExtractor) -> None:
    result = extractor.filter_common_words(["THE", "AAPL", "AND", "MSFT"])
    assert "THE" not in result
    assert "AND" not in result
    assert "AAPL" in result


# 7
def test_filter_common_words_removes_abbreviations(extractor: TickerExtractor) -> None:
    result = extractor.filter_common_words(["CEO", "IPO", "ETF", "NVDA"])
    assert "CEO" not in result
    assert "NVDA" in result


# 8
def test_extract_cashtag_format(extractor: TickerExtractor) -> None:
    result = extractor.extract("$AAPL is looking good today")
    assert "AAPL" in result


# 9
def test_extract_cashtag_appears_before_bare(extractor: TickerExtractor) -> None:
    """Cashtags should come first in the deduplicated result."""
    result = extractor.extract("$TSLA AAPL TSLA")
    assert result[0] == "TSLA"


# 10
def test_extract_deduplicates_tickers(extractor: TickerExtractor) -> None:
    result = extractor.extract("AAPL AAPL AAPL mentioned three times")
    assert result.count("AAPL") == 1


# 11
def test_extract_handles_special_chars(extractor: TickerExtractor) -> None:
    result = extractor.extract("AAPL, MSFT. GOOG!")
    assert "AAPL" in result
    assert "MSFT" in result
    assert "GOOG" in result


# 12
def test_extract_max_length_5_chars(extractor: TickerExtractor) -> None:
    """Six-letter tokens should NOT be extracted."""
    result = extractor.extract("TOOLONG is not a ticker")
    assert "TOOLONG" not in result


# 13
def test_extract_single_letter_not_in_common_words(extractor: TickerExtractor) -> None:
    """'A' is a common word; single-letter non-common-word tickers are very rare."""
    custom = TickerExtractor(common_words=frozenset())
    result = custom.extract("Buy A shares")
    assert "A" in result  # with no common-word filter


# 14
def test_filter_empty_list_returns_empty(extractor: TickerExtractor) -> None:
    assert extractor.filter_common_words([]) == []
