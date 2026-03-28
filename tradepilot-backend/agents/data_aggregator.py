"""DataAggregator agent — collects and normalises raw market data."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from data_pipelines.processors.feature_engineer import CandidateFeatures

from agents.base import BaseAgent


@dataclass
class AggregatorInput:
    tickers: list[str] | None = None


@dataclass
class AggregatorOutput:
    candidates: list[CandidateFeatures] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)


class DataAggregatorAgent(BaseAgent[AggregatorInput, AggregatorOutput]):
    """Collect market prices, options flow, Reddit posts, and news articles.

    Runs four ingestors in parallel, extracts tickers, and surfaces the
    top-50 candidates as feature vectors.  Timeout: 180 min.
    """

    def __init__(self, timeout_seconds: float = 10_800.0) -> None:
        super().__init__(name="DataAggregator", timeout_seconds=timeout_seconds)

    async def _run(self, input_data: AggregatorInput) -> AggregatorOutput:
        self._log.info("data_aggregator.start", tickers=input_data.tickers)
        try:
            # Ingestors are scaffolded; return empty candidate list until wired.
            result = AggregatorOutput(
                candidates=[],
                metadata={"source": "stub", "tickers_requested": input_data.tickers},
            )
            self._log.info("data_aggregator.complete", candidate_count=0)
            return result
        except Exception as exc:
            self._log.error("data_aggregator.error", error=str(exc))
            raise
