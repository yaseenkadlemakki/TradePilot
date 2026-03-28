"""QuantStrategy agent — selects exactly 4 trade proposals."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from typing import Any

from config.constants import StrategyType
from data_pipelines.processors.feature_engineer import CandidateFeatures

from agents.base import BaseAgent


@dataclass
class StrategyInput:
    """Input payload for ``QuantStrategyAgent``."""

    candidates: list[CandidateFeatures]
    run_date: date | None = None


@dataclass
class StrategyOutput:
    """Output payload from ``QuantStrategyAgent``."""

    proposals: list[dict[str, Any]]


class QuantStrategyAgent(BaseAgent[StrategyInput, StrategyOutput]):
    """Select the best candidate per strategy type and compute risk metrics.

    Produces one trade proposal for each ``StrategyType`` (long call, long put,
    short call, short put), choosing the highest- or lowest-scoring candidate
    depending on bullish/bearish bias.
    """

    STRATEGY_TYPES = list(StrategyType)

    def __init__(self, timeout_seconds: float = 600.0) -> None:
        """Initialise the agent with an optional execution timeout.

        Args:
            timeout_seconds: Maximum wall-clock seconds before the run is
                cancelled with ``asyncio.TimeoutError``.
        """
        super().__init__(name="QuantStrategy", timeout_seconds=timeout_seconds)

    async def _run(self, input_data: StrategyInput) -> StrategyOutput:
        """Build one trade proposal per strategy type from *input_data*.

        Args:
            input_data: Candidates and an optional run date.

        Returns:
            ``StrategyOutput`` containing a list of serialisable proposal dicts.

        Raises:
            ValueError: If no candidates are supplied.
        """
        candidates = input_data.candidates
        run_date = input_data.run_date or date.today()

        if not candidates:
            raise ValueError("No candidates supplied to QuantStrategyAgent")

        proposals = [
            self._build_proposal(strategy, candidates, run_date)
            for strategy in self.STRATEGY_TYPES
        ]
        return StrategyOutput(proposals=proposals)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _build_proposal(
        self,
        strategy: StrategyType,
        candidates: list[CandidateFeatures],
        run_date: date,
    ) -> dict[str, Any]:
        """Construct a single trade proposal dict for the given strategy.

        Args:
            strategy: The option strategy type.
            candidates: All available enriched feature vectors.
            run_date: The date the pipeline is running; used to compute expiry.

        Returns:
            A serialisable dict suitable for the recommendations API response.
        """
        candidate = self._select_candidate(strategy, candidates)
        expiry = run_date + timedelta(days=30)
        entry = max(candidate.price * 0.02, 0.50)  # rough option premium
        stop = round(entry * 0.50, 2)
        target = round(entry * 3.00, 2)
        rr = round(target / entry, 2) if entry > 0 else 3.0

        return {
            "ticker": candidate.ticker,
            "strategy_type": strategy.value,
            "strike": round(candidate.price * self._strike_multiplier(strategy), 2),
            "expiry": expiry.isoformat(),
            "entry_price": round(entry, 2),
            "stop_loss": stop,
            "take_profit": target,
            "risk_reward_ratio": rr,
            "composite_score": candidate.composite_score,
            "greeks": {
                "delta": candidate.delta,
                "gamma": candidate.gamma,
                "theta": candidate.theta,
                "vega": candidate.vega,
            },
            "iv": candidate.iv,
            "volume": candidate.options_volume,
            "open_interest": candidate.open_interest,
            "rationale": f"{strategy.value} on {candidate.ticker} "
            f"(score={candidate.composite_score:.3f})",
        }

    @staticmethod
    def _select_candidate(
        strategy: StrategyType, candidates: list[CandidateFeatures]
    ) -> CandidateFeatures:
        """Pick the highest-scoring candidate for the given strategy type.

        Args:
            strategy: The option strategy being evaluated.
            candidates: Pool of enriched feature vectors to choose from.

        Returns:
            The best-fit ``CandidateFeatures`` for *strategy*.
        """
        if strategy in (StrategyType.LONG_CALL, StrategyType.SHORT_PUT):
            # Bullish bias → highest composite score
            return max(candidates, key=lambda c: c.composite_score)
        # Bearish bias → lowest composite score (most negative sentiment)
        return min(candidates, key=lambda c: c.composite_score)

    @staticmethod
    def _strike_multiplier(strategy: StrategyType) -> float:
        """Return the strike price multiplier for a given strategy type.

        Args:
            strategy: The option strategy type.

        Returns:
            A float multiplied against the underlying price to derive the strike.
        """
        return {
            StrategyType.LONG_CALL: 1.05,
            StrategyType.SHORT_CALL: 1.10,
            StrategyType.LONG_PUT: 0.95,
            StrategyType.SHORT_PUT: 0.90,
        }[strategy]
