"""Unit tests for RecommendationService — 12 tests."""

from __future__ import annotations

from datetime import date

import pytest
from services.recommendation_service import RecommendationService


@pytest.fixture()
def service() -> RecommendationService:
    return RecommendationService()


def _fake_pipeline_result(run_date: str | None = None) -> dict:
    return {
        "run_date": run_date or date.today().isoformat(),
        "generated_at": "2025-01-01T00:00:00",
        "recommendations": [
            {"ticker": "AAPL", "strategy_type": "long_call"},
            {"ticker": "MSFT", "strategy_type": "long_put"},
            {"ticker": "NVDA", "strategy_type": "short_call"},
            {"ticker": "TSLA", "strategy_type": "short_put"},
        ],
        "pipeline_duration_seconds": 0.1,
    }


# 1
def test_get_by_date_returns_none_when_empty(service: RecommendationService) -> None:
    result = service.get_by_date(date.today())
    assert result is None


# 2
def test_get_by_id_returns_none_for_unknown_id(service: RecommendationService) -> None:
    result = service.get_by_id("nonexistent-id")
    assert result is None


# 3
def test_run_pipeline_returns_dict_with_id(service: RecommendationService) -> None:
    result = service.run_pipeline()
    assert isinstance(result, dict)
    assert "id" in result


# 4
def test_run_pipeline_stores_result(service: RecommendationService) -> None:
    result = service.run_pipeline()
    rec_id = result["id"]
    stored = service.get_by_id(rec_id)
    assert stored is not None
    assert stored["id"] == rec_id


# 5
def test_get_by_date_finds_stored_result(service: RecommendationService) -> None:
    service.run_pipeline()
    found = service.get_by_date(date.today())
    assert found is not None
    assert found["run_date"] == date.today().isoformat()


# 6
def test_get_history_returns_list(service: RecommendationService) -> None:
    history = service.get_history()
    assert isinstance(history, list)


# 7
def test_get_history_empty_when_no_runs(service: RecommendationService) -> None:
    assert service.get_history() == []


# 8
def test_get_history_returns_stored_runs(service: RecommendationService) -> None:
    service.run_pipeline()
    history = service.get_history()
    assert len(history) >= 1


# 9
def test_get_history_strategy_filter(service: RecommendationService) -> None:
    service.run_pipeline()
    results = service.get_history(strategy="long_call")
    assert isinstance(results, list)
    # All returned entries should contain a long_call recommendation
    for r in results:
        types = [p.get("strategy_type") for p in r.get("recommendations", [])]
        assert "long_call" in types


# 10
def test_get_history_strategy_filter_no_match(service: RecommendationService) -> None:
    service.run_pipeline()
    results = service.get_history(strategy="nonexistent_strategy")
    assert results == []


# 11
def test_get_performance_returns_dict(service: RecommendationService) -> None:
    perf = service.get_performance()
    assert isinstance(perf, dict)
    assert "total_recommendations" in perf
    assert "win_rate" in perf


# 12
def test_get_performance_total_increments_after_run(service: RecommendationService) -> None:
    before = service.get_performance()["total_recommendations"]
    service.run_pipeline()
    after = service.get_performance()["total_recommendations"]
    assert after == before + 1
