"""Shared pytest fixtures."""

from __future__ import annotations

import pytest

from data_pipelines.processors.feature_engineer import CandidateFeatures


@pytest.fixture()
def sample_features() -> CandidateFeatures:
    return CandidateFeatures(
        ticker="AAPL",
        price=180.0,
        price_change_1d=0.05,
        price_change_5d=0.10,
        volume=5_000_000,
        volume_ratio=2.5,
        iv=0.30,
        open_interest=10_000,
        options_volume=3_000,
        bid_ask_spread_pct=0.02,
        sentiment_score=0.60,
        mention_count=150,
        source_diversity=3,
        conviction=0.75,
        delta=0.55,
        gamma=0.02,
        theta=-0.05,
        vega=0.15,
        composite_score=0.70,
    )


@pytest.fixture()
def candidate_list() -> list[CandidateFeatures]:
    data = [
        ("AAPL", 180.0, 0.05, 0.60, 0.80),
        ("MSFT", 350.0, -0.03, -0.50, 0.20),
        ("NVDA", 600.0, 0.10, 0.80, 0.90),
        ("TSLA", 250.0, -0.08, -0.70, 0.15),
        ("AMZN", 180.0, 0.02, 0.20, 0.55),
    ]
    result = []
    for ticker, price, change, sent, score in data:
        result.append(
            CandidateFeatures(
                ticker=ticker,
                price=price,
                price_change_1d=change,
                sentiment_score=sent,
                composite_score=score,
                options_volume=2000,
                open_interest=8000,
                iv=0.30,
            )
        )
    return result
