"""ExpertAdvisor agent — final coherence review and rationale refinement."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from config.constants import MarketRegime

from agents.base import BaseAgent


@dataclass
class AdvisorInput:
    proposals: list[dict[str, Any]]


@dataclass
class AdvisorOutput:
    recommendations: list[dict[str, Any]] = field(default_factory=list)
    market_regime: MarketRegime = MarketRegime.NEUTRAL
    metadata: dict[str, Any] = field(default_factory=dict)


class ExpertAdvisorAgent(BaseAgent[AdvisorInput, AdvisorOutput]):
    """Final coherence review: detects market regime, checks sector concentration,
    refines rationales, and produces the DailyRecommendations payload.
    Timeout: 5 min.
    """

    def __init__(self, timeout_seconds: float = 300.0) -> None:
        super().__init__(name="ExpertAdvisor", timeout_seconds=timeout_seconds)

    async def _run(self, input_data: AdvisorInput) -> AdvisorOutput:
        proposals = input_data.proposals
        if not proposals:
            raise ValueError("No proposals supplied to ExpertAdvisorAgent")

        self._log.info("expert_advisor.start", proposal_count=len(proposals))
        try:
            # Coherence review is scaffolded; pass proposals through unchanged.
            result = AdvisorOutput(
                recommendations=proposals,
                market_regime=MarketRegime.NEUTRAL,
                metadata={"review": "stub"},
            )
            self._log.info(
                "expert_advisor.complete",
                recommendation_count=len(result.recommendations),
                market_regime=result.market_regime.value,
            )
            return result
        except Exception as exc:
            self._log.error("expert_advisor.error", error=str(exc))
            raise
