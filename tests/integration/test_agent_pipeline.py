"""Integration tests for the full agent pipeline — 5 tests."""

from __future__ import annotations

import asyncio
from datetime import date

import pytest

from agents.orchestrator import PipelineOrchestrator, run_pipeline
from data_pipelines.processors.feature_engineer import CandidateFeatures


def run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


@pytest.fixture()
def sample_candidates() -> list[CandidateFeatures]:
    return [
        CandidateFeatures(ticker=t, price=p, composite_score=s, options_volume=2000, open_interest=5000, iv=0.30)
        for t, p, s in [
            ("AAPL", 180.0, 0.85),
            ("MSFT", 350.0, 0.65),
            ("NVDA", 600.0, 0.90),
            ("TSLA", 250.0, 0.25),
            ("AMZN", 185.0, 0.45),
        ]
    ]


# 1
def test_pipeline_returns_4_recommendations(sample_candidates) -> None:
    result = run(run_pipeline(sample_candidates))
    assert len(result["recommendations"]) == 4


# 2
def test_pipeline_result_has_run_date(sample_candidates) -> None:
    result = run(run_pipeline(sample_candidates))
    assert "run_date" in result
    assert result["run_date"] == date.today().isoformat()


# 3
def test_pipeline_result_has_generated_at(sample_candidates) -> None:
    result = run(run_pipeline(sample_candidates))
    assert "generated_at" in result


# 4
def test_pipeline_result_has_duration(sample_candidates) -> None:
    result = run(run_pipeline(sample_candidates))
    assert result["pipeline_duration_seconds"] >= 0


# 5
def test_pipeline_stub_candidates_work_when_none_passed() -> None:
    """run_pipeline() with no args uses built-in stub data."""
    result = run(run_pipeline(None))
    assert len(result["recommendations"]) == 4
