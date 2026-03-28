"""Thin orchestrator that wires the 5-agent pipeline together."""

from __future__ import annotations

import time
from datetime import date, datetime, timezone
from typing import Any

from data_pipelines.processors.feature_engineer import CandidateFeatures

from agents.quant_strategy import QuantStrategyAgent, StrategyInput


class PipelineOrchestrator:
    """Run the 5-agent pipeline and return a DailyRecommendations payload.

    Currently delegates to ``QuantStrategyAgent``; future agents (data
    aggregation, sentiment, risk compliance, expert advisor) will be wired
    in here as they are implemented.
    """

    def __init__(self) -> None:
        """Initialise the orchestrator with all pipeline agents."""
        self._quant = QuantStrategyAgent()

    async def run(self, candidates: list[CandidateFeatures]) -> dict[str, Any]:
        """Execute the pipeline and return a serialisable recommendations payload.

        Args:
            candidates: Pre-enriched feature vectors for ticker candidates.

        Returns:
            Dict with keys ``run_date``, ``generated_at``, ``recommendations``,
            and ``pipeline_duration_seconds``.
        """
        start = time.monotonic()
        strategy_output = await self._quant.run(StrategyInput(candidates=candidates))
        elapsed = time.monotonic() - start

        return {
            "run_date": date.today().isoformat(),
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "recommendations": strategy_output.proposals,
            "pipeline_duration_seconds": round(elapsed, 3),
        }



async def run_pipeline(candidates: list[CandidateFeatures] | None = None) -> dict[str, Any]:
    """Convenience coroutine; uses stub candidates when none supplied.

    Args:
        candidates: Optional list of enriched feature vectors. When ``None``
            or empty, a hardcoded set of five well-known tickers is used for
            development / smoke-testing purposes.

    Returns:
        Recommendations payload from ``PipelineOrchestrator.run``.
    """
    if not candidates:
        candidates = _stub_candidates()
    orchestrator = PipelineOrchestrator()
    return await orchestrator.run(candidates)


def _stub_candidates() -> list[CandidateFeatures]:
    """Return five hardcoded candidate feature vectors used when no real data is available."""
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
