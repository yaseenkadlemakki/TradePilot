"""Health-check endpoints for liveness and readiness probes."""

from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check() -> dict[str, Any]:
    """Return service liveness status and current timestamp.

    Returns:
        Dict with ``status``, ``version``, and ``timestamp`` keys.
    """
    return {
        "status": "ok",
        "version": "0.1.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/health/ready")
async def readiness_probe() -> dict[str, str]:
    """Return service readiness status for orchestration health checks.

    Returns:
        Dict with a single ``status`` key set to ``"ready"``.
    """
    return {"status": "ready"}
