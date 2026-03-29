"""Unit tests for FeatureEngineer composite scoring — 20 tests."""

from __future__ import annotations

import pytest
from data_pipelines.processors.feature_engineer import CandidateFeatures, FeatureEngineer


@pytest.fixture()
def engineer() -> FeatureEngineer:
    return FeatureEngineer()


@pytest.fixture()
def blank_features() -> CandidateFeatures:
    return CandidateFeatures(ticker="TEST")


# 1
def test_default_weights_sum_to_one(engineer: FeatureEngineer) -> None:
    total = sum(engineer._w.values())
    assert abs(total - 1.0) < 1e-9


# 2
def test_compute_returns_float(engineer: FeatureEngineer, blank_features: CandidateFeatures) -> None:
    score = engineer.compute_composite_score(blank_features)
    assert isinstance(score, float)


# 3
def test_compute_score_in_range(engineer: FeatureEngineer, blank_features: CandidateFeatures) -> None:
    score = engineer.compute_composite_score(blank_features)
    assert 0.0 <= score <= 1.0


# 4
def test_all_max_features_gives_score_one() -> None:
    eng = FeatureEngineer()
    f = CandidateFeatures(
        ticker="TOP",
        sentiment_score=1.0,   # maps to 1.0
        price_change_1d=0.20,  # maps to 1.0
        options_volume=10_000, # maps to 1.0
        volume_ratio=10.0,     # maps to 1.0
    )
    score = eng.compute_composite_score(f)
    assert score == 1.0


# 5
def test_all_min_features_gives_score_zero() -> None:
    eng = FeatureEngineer()
    f = CandidateFeatures(
        ticker="BOT",
        sentiment_score=-1.0,   # maps to 0.0
        price_change_1d=-0.20,  # maps to 0.0
        options_volume=0,       # maps to 0.0
        volume_ratio=0.0,       # maps to 0.0
    )
    score = eng.compute_composite_score(f)
    assert score == 0.0


# 6
def test_enrich_sets_composite_score(engineer: FeatureEngineer) -> None:
    f = CandidateFeatures(ticker="AAPL", sentiment_score=0.5, options_volume=5000, volume_ratio=3.0)
    result = engineer.enrich(f)
    assert result.composite_score > 0.0


# 7
def test_enrich_returns_same_object(engineer: FeatureEngineer) -> None:
    f = CandidateFeatures(ticker="AAPL")
    result = engineer.enrich(f)
    assert result is f


# 8
def test_sentiment_score_positive_raises_composite(engineer: FeatureEngineer) -> None:
    base = CandidateFeatures(ticker="X", sentiment_score=0.0)
    high = CandidateFeatures(ticker="X", sentiment_score=1.0)
    assert engineer.compute_composite_score(high) > engineer.compute_composite_score(base)


# 9
def test_options_volume_zero_contributes_nothing(engineer: FeatureEngineer) -> None:
    f_zero = CandidateFeatures(ticker="X", options_volume=0)
    f_high = CandidateFeatures(ticker="X", options_volume=10_000)
    assert engineer.compute_composite_score(f_high) > engineer.compute_composite_score(f_zero)


# 10
def test_options_volume_saturates_at_10000(engineer: FeatureEngineer) -> None:
    f_at = CandidateFeatures(ticker="X", options_volume=10_000)
    f_over = CandidateFeatures(ticker="X", options_volume=100_000)
    # Both should give identical options component (capped at 1.0)
    assert engineer.compute_composite_score(f_at) == engineer.compute_composite_score(f_over)


# 11
def test_volume_ratio_clamps_below_zero(engineer: FeatureEngineer) -> None:
    f = CandidateFeatures(ticker="X", volume_ratio=-5.0)
    score = engineer.compute_composite_score(f)
    assert 0.0 <= score <= 1.0


# 12
def test_custom_weights_applied() -> None:
    eng = FeatureEngineer(sentiment_weight=1.0, momentum_weight=0.0, options_flow_weight=0.0, technical_weight=0.0)
    f_pos = CandidateFeatures(ticker="X", sentiment_score=1.0)
    f_neg = CandidateFeatures(ticker="X", sentiment_score=-1.0)
    assert eng.compute_composite_score(f_pos) == 1.0
    assert eng.compute_composite_score(f_neg) == 0.0


# 13
def test_momentum_component_boundary_low(engineer: FeatureEngineer) -> None:
    # price_change_1d at exactly -0.20 maps momentum_component to 0.0
    f = CandidateFeatures(ticker="X", price_change_1d=-0.20)
    score = engineer.compute_composite_score(f)
    assert score >= 0.0


# 14
def test_momentum_component_boundary_high(engineer: FeatureEngineer) -> None:
    # price_change_1d at exactly 0.20 maps momentum_component to 1.0
    f_high = CandidateFeatures(ticker="X", price_change_1d=0.20)
    f_mid = CandidateFeatures(ticker="X", price_change_1d=0.0)
    assert engineer.compute_composite_score(f_high) > engineer.compute_composite_score(f_mid)


# 15
def test_score_is_rounded_to_6_decimals(engineer: FeatureEngineer) -> None:
    f = CandidateFeatures(ticker="X", sentiment_score=0.33, price_change_1d=0.07)
    score = engineer.compute_composite_score(f)
    assert score == round(score, 6)


# 16
def test_candidate_features_defaults() -> None:
    f = CandidateFeatures(ticker="BARE")
    assert f.price == 0.0
    assert f.composite_score == 0.0
    assert f.tags == []


# 17
def test_candidate_features_tags_are_independent() -> None:
    f1 = CandidateFeatures(ticker="A")
    f2 = CandidateFeatures(ticker="B")
    f1.tags.append("moon")
    assert "moon" not in f2.tags


# 18
def test_high_volume_ratio_gives_high_technical_component(engineer: FeatureEngineer) -> None:
    f = CandidateFeatures(ticker="X", volume_ratio=10.0)
    # technical_component = min(1.0, 10.0/10.0) = 1.0
    # score contribution from technical = 0.20 * 1.0
    f_low = CandidateFeatures(ticker="X", volume_ratio=1.0)
    assert engineer.compute_composite_score(f) > engineer.compute_composite_score(f_low)


# 19
def test_negative_sentiment_score_lowers_composite(engineer: FeatureEngineer) -> None:
    f_pos = CandidateFeatures(ticker="X", sentiment_score=0.8)
    f_neg = CandidateFeatures(ticker="X", sentiment_score=-0.8)
    assert engineer.compute_composite_score(f_pos) > engineer.compute_composite_score(f_neg)


# 20
def test_enrich_overwrites_existing_composite_score(engineer: FeatureEngineer) -> None:
    f = CandidateFeatures(ticker="X", composite_score=0.99)
    engineer.enrich(f)
    # After enrich, score is recomputed (should be 0.0 given defaults)
    assert f.composite_score != 0.99
