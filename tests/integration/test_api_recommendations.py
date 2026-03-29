"""Extended integration tests for recommendations API endpoints — 14 tests."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient


@pytest.fixture()
def fresh_client() -> TestClient:
    """Use a fresh app instance via a clean TestClient."""
    from api.main import create_app
    return TestClient(create_app())


# 1 — /today returns either 200 (if already populated) or 404; either way must be valid JSON
def test_get_today_returns_valid_response(fresh_client: TestClient) -> None:
    response = fresh_client.get("/api/v1/recommendations/today")
    assert response.status_code in (200, 404)
    assert response.json() is not None


# 2 — when /today returns 404, the body has a "detail" key
def test_get_today_404_or_populated(fresh_client: TestClient) -> None:
    response = fresh_client.get("/api/v1/recommendations/today")
    body = response.json()
    if response.status_code == 404:
        assert "detail" in body
    else:
        assert response.status_code == 200


# 3 — A non-date path segment triggers a 422 validation error
def test_get_by_date_invalid_format_returns_422(fresh_client: TestClient) -> None:
    # "notadate" cannot be parsed as a date
    response = fresh_client.get("/api/v1/recommendations/notadate")
    assert response.status_code == 422


# 4 — A valid future date that has no data returns 404
def test_get_by_date_valid_future_date_returns_404(fresh_client: TestClient) -> None:
    response = fresh_client.get("/api/v1/recommendations/2099-12-31")
    assert response.status_code == 404


# 5 — detail/{rec_id} for an unknown id returns 404
def test_get_detail_unknown_id_returns_404(fresh_client: TestClient) -> None:
    response = fresh_client.get("/api/v1/recommendations/detail/00000000-0000-0000-0000-000000000000")
    assert response.status_code == 404


# 6 — 404 detail message contains the requested id
def test_get_detail_404_error_detail_contains_id(fresh_client: TestClient) -> None:
    rec_id = "00000000-0000-0000-0000-000000000000"
    response = fresh_client.get(f"/api/v1/recommendations/detail/{rec_id}")
    assert rec_id in response.json()["detail"]


# 7 — POST /trigger returns 200
def test_trigger_pipeline_returns_200(fresh_client: TestClient) -> None:
    response = fresh_client.post("/api/v1/recommendations/trigger")
    assert response.status_code == 200


# 8 — POST /trigger returns triggered status
def test_trigger_pipeline_returns_triggered_status(fresh_client: TestClient) -> None:
    response = fresh_client.post("/api/v1/recommendations/trigger")
    assert response.json()["status"] == "triggered"


# 9 — POST /trigger returns message key
def test_trigger_pipeline_returns_message(fresh_client: TestClient) -> None:
    response = fresh_client.post("/api/v1/recommendations/trigger")
    assert "message" in response.json()


# 10 — /health/ready returns 200
def test_health_ready_returns_200(fresh_client: TestClient) -> None:
    response = fresh_client.get("/health/ready")
    assert response.status_code == 200


# 11 — /health/ready status is "ready"
def test_health_ready_returns_ready_status(fresh_client: TestClient) -> None:
    response = fresh_client.get("/health/ready")
    assert response.json()["status"] == "ready"


# 12 — /health returns timestamp key
def test_health_has_timestamp(fresh_client: TestClient) -> None:
    response = fresh_client.get("/health")
    assert "timestamp" in response.json()


# 13 — /health version is 0.1.0
def test_health_version_is_correct(fresh_client: TestClient) -> None:
    response = fresh_client.get("/health")
    assert response.json()["version"] == "0.1.0"


# 14 — 404 for a past date that has no data
def test_get_by_date_past_date_returns_404(fresh_client: TestClient) -> None:
    response = fresh_client.get("/api/v1/recommendations/2000-01-01")
    assert response.status_code == 404
