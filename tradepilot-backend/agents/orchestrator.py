"""Thin orchestrator that wires the 5-agent pipeline together."""

from __future__ import annotations

import time
from datetime import date, datetime

from data_pipelines.processors.feature_engineer import CandidateFeatures

from agents.quant_strategy import QuantStrategyAgent, StrategyInput


class PipelineOrchestrator:
    """Run the 5-agent pipeline and return a DailyRecommendations payload."""

    def __init__(self) -> None:
        self._quant = QuantStrategyAgent()

    async def run(self, candidates: list[CandidateFeatures]) -> dict:
        start = time.monotonic()
        strategy_output = await self._quant.run(StrategyInput(candidates=candidates))
        elapsed = time.monotonic() - start

        return {
            "run_date": date.today().isoformat(),
            "generated_at": datetime.utcnow().isoformat(),
            "recommendations": strategy_output.proposals,
            "pipeline_duration_seconds": round(elapsed, 3),
        }

    async def run_async(self, candidates: list[CandidateFeatures]) -> dict:
        return await self.run(candidates)


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
