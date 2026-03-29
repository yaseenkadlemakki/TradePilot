"""Integration tests for FastAPI endpoints — 6 tests."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from api.main import app


@pytest.fixture(scope="module")
def client() -> TestClient:
    return TestClient(app)


# 1
def test_health_check_returns_200(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200


# 2
def test_health_check_has_status_ok(client: TestClient) -> None:
    response = client.get("/health")
    assert response.json()["status"] == "ok"


# 3
def test_health_ready_returns_200(client: TestClient) -> None:
    response = client.get("/health/ready")
    assert response.status_code == 200


# 4
def test_today_recommendations_returns_404_when_empty(client: TestClient) -> None:
    response = client.get("/api/v1/recommendations/today")
    assert response.status_code == 404


# 5
def test_trigger_pipeline_returns_200(client: TestClient) -> None:
    response = client.post("/api/v1/recommendations/trigger")
    assert response.status_code == 200
    assert response.json()["status"] == "triggered"


# 6
def test_health_check_has_version(client: TestClient) -> None:
    response = client.get("/health")
    body = response.json()
    assert "version" in body
