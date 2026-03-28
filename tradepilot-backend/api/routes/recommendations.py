"""REST endpoints for trade recommendations."""

from __future__ import annotations

from datetime import date
from typing import Any, Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException
from services.recommendation_service import RecommendationService

router = APIRouter(prefix="/api/v1/recommendations")
_service = RecommendationService()


@router.get("/today")
async def get_today() -> dict[str, Any]:
    """Return today's recommendation payload.

    Returns:
        The recommendation payload for the current calendar date.

    Raises:
        HTTPException: 404 if no pipeline run exists for today.
    """
    result = _service.get_by_date(date.today())
    if result is None:
        raise HTTPException(status_code=404, detail="No recommendations for today yet")
    return result


@router.get("/{run_date}")
async def get_by_date(run_date: date) -> dict[str, Any]:
    """Return the recommendation payload for a specific date.

    Args:
        run_date: ISO-format date string parsed by FastAPI (e.g. ``2024-01-15``).

    Returns:
        The recommendation payload for *run_date*.

    Raises:
        HTTPException: 404 if no pipeline run exists for *run_date*.
    """
    result = _service.get_by_date(run_date)
    if result is None:
        raise HTTPException(status_code=404, detail=f"No recommendations for {run_date}")
    return result


@router.get("/detail/{rec_id}")
async def get_detail(rec_id: str) -> dict[str, Any]:
    """Return a recommendation payload by its UUID.

    Args:
        rec_id: UUID string assigned at pipeline run time.

    Returns:
        The matching recommendation payload.

    Raises:
        HTTPException: 404 if *rec_id* is not found.
    """
    result = _service.get_by_id(rec_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Recommendation {rec_id} not found")
    return result


@router.get("/history")
async def get_history(days: int = 30, strategy: Optional[str] = None) -> dict[str, Any]:
    """Return recent recommendation history, optionally filtered by strategy type.

    Args:
        days: Number of most-recent records to return (clamped to 1–90).
        strategy: Optional strategy type filter (e.g. ``"long_call"``).

    Returns:
        Dict with a ``history`` key containing the list of payload dicts.
    """
    days = max(1, min(90, days))
    return {"history": _service.get_history(days=days, strategy=strategy)}


@router.get("/performance")
async def get_performance() -> dict[str, Any]:
    """Return aggregate performance metrics for all stored recommendations.

    Returns:
        Dict with ``total_recommendations``, ``win_rate``, ``avg_return``,
        and ``sharpe_ratio``.
    """
    return _service.get_performance()


@router.post("/trigger")
async def trigger_pipeline(background_tasks: BackgroundTasks) -> dict[str, str]:
    """Queue the recommendation pipeline for asynchronous execution.

    Args:
        background_tasks: FastAPI background-task manager injected automatically.

    Returns:
        Dict with ``status`` and ``message`` keys confirming the task was queued.
    """
    background_tasks.add_task(_service.run_pipeline)
    return {"status": "triggered", "message": "Pipeline queued for execution"}
