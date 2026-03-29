"""Thin orchestrator that wires the 5-agent pipeline together."""

from __future__ import annotations

import time
from datetime import date, datetime, timezone

import structlog
from data_pipelines.processors.feature_engineer import CandidateFeatures

from agents.base import AgentError
from agents.quant_strategy import QuantStrategyAgent, StrategyInput

log = structlog.get_logger(__name__)


class PipelineOrchestrator:
    """Run the 5-agent pipeline and return a DailyRecommendations payload."""

    def __init__(self) -> None:
        self._quant = QuantStrategyAgent()

    async def run(self, candidates: list[CandidateFeatures]) -> dict:
        start = time.monotonic()
        run_date = date.today().isoformat()
        log.info("pipeline.start", run_date=run_date, candidate_count=len(candidates))

        try:
            strategy_output = await self._quant.run(StrategyInput(candidates=candidates))
        except Exception as exc:
            elapsed = time.monotonic() - start
            log.error(
                "pipeline.error",
                duration_seconds=round(elapsed, 3),
                error=str(exc),
                exc_type=type(exc).__name__,
            )
            raise AgentError("PipelineOrchestrator", f"Pipeline failed: {exc}") from exc

        elapsed = time.monotonic() - start
        log.info("pipeline.complete", duration_seconds=round(elapsed, 3), proposal_count=len(strategy_output.proposals))

        return {
            "run_date": run_date,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "recommendations": strategy_output.proposals,
            "pipeline_duration_seconds": round(elapsed, 3),
        }


async def run_pipeline(candidates: list[CandidateFeatures] | None = None) -> dict:
    """Convenience coroutine; uses stub candidates when none supplied."""
    if not candidates:
        candidates = _stub_candidates()
    orchestrator = PipelineOrchestrator()
    return await orchestrator.run(candidates)


def _stub_candidates() -> list[CandidateFeatures]:
    tickers = ["AAPL", "MSFT", "NVDA", "TSLA", "AMZN"]
    return [
        CandidateFeatures(
            ticker=t,
            price=100.0 + i * 10,
            composite_score=0.5 + i * 0.05,
            options_volume=1000 * (i + 1),
            open_interest=5000 * (i + 1),
            iv=0.30 + i * 0.05,
        )
        for i, t in enumerate(tickers)
    ]
