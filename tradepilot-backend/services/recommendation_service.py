"""In-memory recommendation service (no external DB required)."""

from __future__ import annotations

import uuid
from datetime import date
from typing import Any

from agents.orchestrator import run_pipeline


class RecommendationService:
    def __init__(self) -> None:
        self._store: dict[str, dict[str, Any]] = {}  # id -> recommendation payload

    # ------------------------------------------------------------------
    # Reads
    # ------------------------------------------------------------------

    def get_by_date(self, run_date: date) -> dict[str, Any] | None:
        for payload in self._store.values():
            if payload.get("run_date") == run_date.isoformat():
                return payload
        return None

    def get_by_id(self, rec_id: str) -> dict[str, Any] | None:
        return self._store.get(rec_id)

    def get_history(self, days: int = 30, strategy: str | None = None) -> list[dict[str, Any]]:
        results = list(self._store.values())
        if strategy:
            results = [
                r for r in results
                if any(p.get("strategy_type") == strategy for p in r.get("recommendations", []))
            ]
        return results[-days:]

    def get_performance(self) -> dict[str, Any]:
        return {
            "total_recommendations": len(self._store),
            "win_rate": 0.0,
            "avg_return": 0.0,
            "sharpe_ratio": 0.0,
        }

    # ------------------------------------------------------------------
    # Pipeline trigger
    # ------------------------------------------------------------------

    async def run_pipeline(self) -> dict[str, Any]:
        result = await run_pipeline()
        rec_id = str(uuid.uuid4())
        result["id"] = rec_id
        self._store[rec_id] = result
        return result
