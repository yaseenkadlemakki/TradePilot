"""Unit tests for PipelineOrchestrator and run_pipeline — 8 tests."""

from __future__ import annotations

from datetime import date

import pytest
from agents.orchestrator import PipelineOrchestrator, run_pipeline
from data_pipelines.processors.feature_engineer import CandidateFeatures


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
async def test_orchestrator_run_returns_dict(orchestrator, minimal_candidates) -> None:
    result = await orchestrator.run(minimal_candidates)
    assert isinstance(result, dict)


# 2
async def test_orchestrator_result_keys(orchestrator, minimal_candidates) -> None:
    result = await orchestrator.run(minimal_candidates)
    assert "run_date" in result
    assert "generated_at" in result
    assert "recommendations" in result
    assert "pipeline_duration_seconds" in result


# 3
async def test_orchestrator_run_date_is_today(orchestrator, minimal_candidates) -> None:
    result = await orchestrator.run(minimal_candidates)
    assert result["run_date"] == date.today().isoformat()


# 4
async def test_orchestrator_produces_4_proposals(orchestrator, minimal_candidates) -> None:
    result = await orchestrator.run(minimal_candidates)
    assert len(result["recommendations"]) == 4


# 5
async def test_orchestrator_duration_is_non_negative(orchestrator, minimal_candidates) -> None:
    result = await orchestrator.run(minimal_candidates)
    assert result["pipeline_duration_seconds"] >= 0.0


# 6
async def test_run_async_alias(orchestrator, minimal_candidates) -> None:
    result = await orchestrator.run_async(minimal_candidates)
    assert len(result["recommendations"]) == 4


# 7 — test _stub_candidates behaviour through the public run_pipeline() interface
async def test_run_pipeline_empty_list_uses_stubs_and_returns_5_tickers() -> None:
    """When run_pipeline receives an empty list it falls back to stub candidates.

    The stubs contain exactly 5 tickers (AAPL, MSFT, NVDA, TSLA, AMZN) and the
    pipeline selects 4 strategies from them.
    """
    result = await run_pipeline([])
    assert len(result["recommendations"]) == 4
    tickers = {r["ticker"] for r in result["recommendations"]}
    # All selected tickers must come from the known stub set
    assert tickers <= {"AAPL", "MSFT", "NVDA", "TSLA", "AMZN"}


# 8
async def test_run_pipeline_empty_list_uses_stubs() -> None:
    result = await run_pipeline([])
    assert len(result["recommendations"]) == 4
