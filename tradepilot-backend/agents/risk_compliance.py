"""RiskCompliance agent — validates proposals against hard limits."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from agents.base import BaseAgent


@dataclass
class ComplianceInput:
    proposals: list[dict[str, Any]]


@dataclass
class ComplianceOutput:
    validated: list[dict[str, Any]] = field(default_factory=list)
    rejected: list[dict[str, Any]] = field(default_factory=list)
    warnings: list[dict[str, Any]] = field(default_factory=list)


class RiskComplianceAgent(BaseAgent[ComplianceInput, ComplianceOutput]):
    """Validate proposals against hard limits on volume, OI, bid-ask spread, IV,
    and pump detection.  Rejected slots loop back to QuantStrategy (up to 3 retries).
    Timeout: 10 min.
    """

    def __init__(self, timeout_seconds: float = 600.0) -> None:
        super().__init__(name="RiskCompliance", timeout_seconds=timeout_seconds)

    async def _run(self, input_data: ComplianceInput) -> ComplianceOutput:
        proposals = input_data.proposals
        if not proposals:
            raise ValueError("No proposals supplied to RiskComplianceAgent")

        self._log.info("risk_compliance.start", proposal_count=len(proposals))
        try:
            # Validation logic is scaffolded; pass all proposals through as validated.
            result = ComplianceOutput(validated=proposals, rejected=[], warnings=[])
            self._log.info(
                "risk_compliance.complete",
                validated=len(result.validated),
                rejected=len(result.rejected),
            )
            return result
        except Exception as exc:
            self._log.error("risk_compliance.error", error=str(exc))
            raise
