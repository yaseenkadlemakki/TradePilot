from __future__ import annotations

from datetime import date
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException
from services.recommendation_service import RecommendationService

router = APIRouter(prefix="/api/v1/recommendations")
_service = RecommendationService()


@router.get("/today")
async def get_today() -> dict:
    result = _service.get_by_date(date.today())
    if result is None:
        raise HTTPException(status_code=404, detail="No recommendations for today yet")
    return result


@router.get("/history")
async def get_history(days: int = 30, strategy: Optional[str] = None) -> dict:
    days = max(1, min(90, days))
    return {"history": _service.get_history(days=days, strategy=strategy)}


@router.get("/performance")
async def get_performance() -> dict:
    return _service.get_performance()


@router.post("/trigger")
async def trigger_pipeline(background_tasks: BackgroundTasks) -> dict:
    background_tasks.add_task(_service.run_pipeline)
    return {"status": "triggered", "message": "Pipeline queued for execution"}


@router.get("/detail/{rec_id}")
async def get_detail(rec_id: str) -> dict:
    result = _service.get_by_id(rec_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Recommendation {rec_id} not found")
    return result


@router.get("/{run_date}")
async def get_by_date(run_date: date) -> dict:
    result = _service.get_by_date(run_date)
    if result is None:
        raise HTTPException(status_code=404, detail=f"No recommendations for {run_date}")
    return result
