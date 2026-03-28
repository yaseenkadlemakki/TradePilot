"""Unit tests for PumpDetector — 14 tests."""

import pytest

from models.pump_detector import PumpDetector


@pytest.fixture()
def detector() -> PumpDetector:
    return PumpDetector()


def _normal_features() -> dict:
    return {"volume_ratio": 1.2, "price_velocity": 0.01, "social_momentum": 0.10}


def _pump_features() -> dict:
    return {"volume_ratio": 12.0, "price_velocity": 0.25, "social_momentum": 0.95}


# 1
def test_score_returns_float(detector: PumpDetector) -> None:
    assert isinstance(detector.score(_normal_features()), float)


# 2
def test_score_range_is_0_to_1(detector: PumpDetector) -> None:
    for features in [_normal_features(), _pump_features()]:
        s = detector.score(features)
        assert 0.0 <= s <= 1.0


# 3
def test_normal_features_below_threshold(detector: PumpDetector) -> None:
    assert detector.score(_normal_features()) < detector.threshold


# 4
def test_pump_features_above_threshold(detector: PumpDetector) -> None:
    assert detector.score(_pump_features()) >= detector.threshold


# 5
def test_detect_returns_false_for_normal(detector: PumpDetector) -> None:
    assert detector.detect(_normal_features()) is False


# 6
def test_detect_returns_true_for_pump(detector: PumpDetector) -> None:
    assert detector.detect(_pump_features()) is True


# 7
def test_high_volume_ratio_raises_score(detector: PumpDetector) -> None:
    low = detector.score({"volume_ratio": 1.0, "price_velocity": 0.0, "social_momentum": 0.0})
    high = detector.score({"volume_ratio": 10.0, "price_velocity": 0.0, "social_momentum": 0.0})
    assert high > low


# 8
def test_high_price_velocity_raises_score(detector: PumpDetector) -> None:
    low = detector.score({"volume_ratio": 1.0, "price_velocity": 0.0, "social_momentum": 0.0})
    high = detector.score({"volume_ratio": 1.0, "price_velocity": 0.40, "social_momentum": 0.0})
    assert high > low


# 9
def test_high_social_momentum_raises_score(detector: PumpDetector) -> None:
    low = detector.score({"volume_ratio": 1.0, "price_velocity": 0.0, "social_momentum": 0.0})
    high = detector.score({"volume_ratio": 1.0, "price_velocity": 0.0, "social_momentum": 1.0})
    assert high > low


# 10
def test_missing_features_default_to_zero(detector: PumpDetector) -> None:
    score = detector.score({})
    assert score == 0.0


# 11
def test_volume_score_saturates_at_one(detector: PumpDetector) -> None:
    s1 = detector.score({"volume_ratio": 100.0, "price_velocity": 0.0, "social_momentum": 0.0})
    s2 = detector.score({"volume_ratio": 1000.0, "price_velocity": 0.0, "social_momentum": 0.0})
    assert s1 == s2  # both should saturate at max


# 12
def test_custom_threshold(detector: PumpDetector) -> None:
    # normal_features score ≈ 0.049; a threshold of 0.01 must trigger
    low_threshold = PumpDetector(threshold=0.01)
    assert low_threshold.detect(_normal_features()) is True


# 13
def test_borderline_case(detector: PumpDetector) -> None:
    """Score near the threshold should not error."""
    features = {"volume_ratio": 5.0, "price_velocity": 0.10, "social_momentum": 0.60}
    score = detector.score(features)
    assert 0.0 <= score <= 1.0


# 14
def test_extreme_pump_score_is_one(detector: PumpDetector) -> None:
    features = {"volume_ratio": 9999.0, "price_velocity": 9999.0, "social_momentum": 1.0}
    assert detector.score(features) == 1.0
