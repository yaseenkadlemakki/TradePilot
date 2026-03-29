"""Unit tests for SentimentScorer — 14 tests."""

import pytest

from data_pipelines.processors.sentiment_scorer import SentimentScorer


@pytest.fixture()
def scorer() -> SentimentScorer:
    return SentimentScorer()


# 1
def test_positive_sentiment_returns_positive_score(scorer: SentimentScorer) -> None:
    score = scorer.score("AAPL is bullish strong breakout rally to the moon")
    assert score > 0


# 2
def test_negative_sentiment_returns_negative_score(scorer: SentimentScorer) -> None:
    score = scorer.score("TSLA is bearish crash dump selloff collapse")
    assert score < 0


# 3
def test_neutral_text_returns_zero(scorer: SentimentScorer) -> None:
    score = scorer.score("the quick brown fox jumped over the lazy dog")
    assert score == 0.0


# 4
def test_empty_string_returns_zero(scorer: SentimentScorer) -> None:
    assert scorer.score("") == 0.0


# 5
def test_score_is_float(scorer: SentimentScorer) -> None:
    assert isinstance(scorer.score("bullish moon"), float)


# 6
def test_score_range_positive_capped_at_one(scorer: SentimentScorer) -> None:
    very_bullish = " ".join(["bullish", "moon", "rocket", "surge", "rally", "breakout", "gains"] * 10)
    score = scorer.score(very_bullish)
    assert score <= 1.0


# 7
def test_score_range_negative_capped_at_minus_one(scorer: SentimentScorer) -> None:
    very_bearish = " ".join(["bearish", "crash", "dump", "decline", "fall", "collapse"] * 10)
    score = scorer.score(very_bearish)
    assert score >= -1.0


# 8
def test_batch_scoring_returns_list(scorer: SentimentScorer) -> None:
    texts = ["bullish moon", "bearish crash", "neutral text"]
    result = scorer.score_batch(texts)
    assert isinstance(result, list)


# 9
def test_batch_scoring_correct_length(scorer: SentimentScorer) -> None:
    texts = ["one", "two", "three", "four"]
    result = scorer.score_batch(texts)
    assert len(result) == 4


# 10
def test_batch_empty_list(scorer: SentimentScorer) -> None:
    assert scorer.score_batch([]) == []


# 11
def test_mixed_sentiment_score_between_extremes(scorer: SentimentScorer) -> None:
    score = scorer.score("bullish breakout but also crash decline")
    assert -1.0 <= score <= 1.0


# 12
def test_score_case_insensitive(scorer: SentimentScorer) -> None:
    """Scorer lowercases; should detect 'BULLISH' and 'bullish' the same."""
    s1 = scorer.score("BULLISH MOON ROCKET")
    s2 = scorer.score("bullish moon rocket")
    assert s1 == s2


# 13
def test_conviction_score_range(scorer: SentimentScorer) -> None:
    conviction = scorer.conviction_score("bullish rally moon")
    assert 0.0 <= conviction <= 1.0


# 14
def test_conviction_score_empty(scorer: SentimentScorer) -> None:
    assert scorer.conviction_score("") == 0.0
