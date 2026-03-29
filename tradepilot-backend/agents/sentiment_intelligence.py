"""SentimentIntelligence agent — scores sentiment and conviction per candidate."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from data_pipelines.processors.feature_engineer import CandidateFeatures

from agents.base import BaseAgent


@dataclass
class SentimentInput:
    candidates: list[CandidateFeatures]


@dataclass
class SentimentOutput:
    candidates: list[CandidateFeatures] = field(default_factory=list)
    report: dict[str, Any] = field(default_factory=dict)


class SentimentIntelligenceAgent(BaseAgent[SentimentInput, SentimentOutput]):
    """Score each candidate on sentiment, momentum, conviction, and source diversity.

    Optionally calls Claude for deep analysis on the top-25 candidates.
    Timeout: 15 min.
    """

    def __init__(self, timeout_seconds: float = 900.0) -> None:
        super().__init__(name="SentimentIntelligence", timeout_seconds=timeout_seconds)

    async def _run(self, input_data: SentimentInput) -> SentimentOutput:
        candidates = input_data.candidates
        if not candidates:
            raise ValueError("No candidates supplied to SentimentIntelligenceAgent")

        # Sentiment scoring is scaffolded; pass candidates through unchanged.
        return SentimentOutput(candidates=candidates, report={"scorer": "stub"})
