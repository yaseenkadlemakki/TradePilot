"""In-memory recommendation service (no external DB required)."""

from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from agents.orchestrator import run_pipeline

# TODO: Replace in-memory _store with a persistent database backend.
#       Suggested approach: inject a repository/DAO that abstracts TimescaleDB
#       or PostgreSQL. The service interface (get_by_date, get_by_id, etc.)
#       should remain unchanged — only the storage layer needs swapping.


class RecommendationService:
    """Service layer for creating and retrieving trade recommendations.

    Currently uses an in-memory dict keyed by UUID as a persistence layer.
    All data is lost on process restart; see the TODO above for DB integration.
    """

    def __init__(self) -> None:
        """Initialise the service with an empty in-memory store."""
        # TODO: Replace with DB session / repository injection when persistence is added.
        self._store: dict[str, dict[str, Any]] = {}  # id -> recommendation payload

    # ------------------------------------------------------------------
    # Reads
    # ------------------------------------------------------------------

    def get_by_date(self, run_date: date) -> dict[str, Any] | None:
        """Return the recommendation payload for a specific run date, or None.

        Args:
            run_date: The calendar date to look up.

        Returns:
            The matching payload dict, or ``None`` if no run exists for that date.
        """
        for payload in self._store.values():
            if payload.get("run_date") == run_date.isoformat():
                return payload
        return None

    def get_by_id(self, rec_id: str) -> dict[str, Any] | None:
        """Return a recommendation payload by its UUID, or None if not found.

        Args:
            rec_id: UUID string assigned at pipeline run time.

        Returns:
            The matching payload dict, or ``None``.
        """
        return self._store.get(rec_id)

    def get_history(self, days: int = 30, strategy: str | None = None) -> list[dict[str, Any]]:
        """Return up to *days* recent recommendation payloads, optionally filtered.

        Args:
            days: Maximum number of records to return (most recent first).
            strategy: If provided, only include payloads that contain at least one
                proposal of this strategy type.

        Returns:
            A list of payload dicts, newest last (insertion order).

        Note:
            The current implementation returns the last *days* records by
            insertion order. TODO: Sort by ``run_date`` once DB is integrated.
        """
        results = list(self._store.values())
        if strategy:
            results = [
                r for r in results
                if any(p.get("strategy_type") == strategy for p in r.get("recommendations", []))
            ]
        return results[-days:]

    def get_performance(self) -> dict[str, Any]:
        """Return aggregate performance metrics for all stored recommendations.

        Returns:
            Dict with ``total_recommendations``, ``win_rate``, ``avg_return``,
            and ``sharpe_ratio``.

        Note:
            ``win_rate``, ``avg_return``, and ``sharpe_ratio`` are placeholders.
            TODO: Compute these from actual trade outcome tracking once a
            position-tracking module is implemented.
        """
        return {
            "total_recommendations": len(self._store),
            "win_rate": 0.0,       # TODO: compute from tracked outcomes
            "avg_return": 0.0,     # TODO: compute from tracked outcomes
            "sharpe_ratio": 0.0,   # TODO: compute from tracked outcomes
        }

    # ------------------------------------------------------------------
    # Pipeline trigger
    # ------------------------------------------------------------------

    async def run_pipeline(self) -> dict[str, Any]:
        """Execute the recommendation pipeline and persist the result.

        Returns:
            The freshly generated recommendation payload including its assigned ``id``.
        """
        result = await run_pipeline()
        rec_id = str(uuid.uuid4())
        result["id"] = rec_id
        self._store[rec_id] = result
        return result
