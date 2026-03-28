from datetime import datetime

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check() -> dict:
    return {
        "status": "ok",
        "version": "0.1.0",
        "timestamp": datetime.utcnow().isoformat(),
    }


@router.get("/health/ready")
async def readiness_probe() -> dict:
    return {"status": "ready"}
