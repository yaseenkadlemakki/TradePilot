"""Unit tests for PipelineOrchestrator and run_pipeline — 8 tests."""

from __future__ import annotations

import asyncio
from datetime import date

import pytest
from agents.orchestrator import PipelineOrchestrator, _stub_candidates, run_pipeline
from data_pipelines.processors.feature_engineer import CandidateFeatures


def run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


@pytest.fixture()
def orchestrator() -> PipelineOrchestrator:
    return PipelineOrchestrator()


@pytest.fixture()
def minimal_candidates() -> list[CandidateFeatures]:
    return [
        CandidateFeatures(ticker=t, price=p, composite_score=s, options_volume=1000, open_interest=3000, iv=0.30)
        for t, p, s in [
            ("AAPL", 180.0, 0.85),
            ("MSFT", 350.0, 0.65),
            ("NVDA", 600.0, 0.90),
            ("TSLA", 250.0, 0.20),
            ("AMZN", 185.0, 0.50),
        ]
    ]


# 1
def test_orchestrator_run_returns_dict(orchestrator, minimal_candidates) -> None:
    result = run(orchestrator.run(minimal_candidates))
    assert isinstance(result, dict)


# 2
def test_orchestrator_result_keys(orchestrator, minimal_candidates) -> None:
    result = run(orchestrator.run(minimal_candidates))
    assert "run_date" in result
    assert "generated_at" in result
    assert "recommendations" in result
    assert "pipeline_duration_seconds" in result


# 3
def test_orchestrator_run_date_is_today(orchestrator, minimal_candidates) -> None:
    result = run(orchestrator.run(minimal_candidates))
    assert result["run_date"] == date.today().isoformat()


# 4
def test_orchestrator_produces_4_proposals(orchestrator, minimal_candidates) -> None:
    result = run(orchestrator.run(minimal_candidates))
    assert len(result["recommendations"]) == 4


# 5
def test_orchestrator_duration_is_non_negative(orchestrator, minimal_candidates) -> None:
    result = run(orchestrator.run(minimal_candidates))
    assert result["pipeline_duration_seconds"] >= 0.0


# 6
def test_run_async_alias(orchestrator, minimal_candidates) -> None:
    result = run(orchestrator.run_async(minimal_candidates))
    assert len(result["recommendations"]) == 4


# 7
def test_stub_candidates_generates_5_tickers() -> None:
    stubs = _stub_candidates()
    assert len(stubs) == 5
    tickers = [c.ticker for c in stubs]
    assert "AAPL" in tickers
    assert "NVDA" in tickers


# 8
def test_run_pipeline_empty_list_uses_stubs() -> None:
    result = run(run_pipeline([]))
    assert len(result["recommendations"]) == 4
