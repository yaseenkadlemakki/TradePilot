"""Unit tests for QuantStrategyAgent — 14 tests."""

from __future__ import annotations

import asyncio
from datetime import date

import pytest

from agents.quant_strategy import QuantStrategyAgent, StrategyInput
from config.constants import StrategyType
from data_pipelines.processors.feature_engineer import CandidateFeatures


def run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


@pytest.fixture()
def agent() -> QuantStrategyAgent:
    return QuantStrategyAgent()


@pytest.fixture()
def candidates() -> list[CandidateFeatures]:
    return [
        CandidateFeatures(ticker="AAPL", price=180.0, composite_score=0.80, options_volume=3000, open_interest=10000, iv=0.30),
        CandidateFeatures(ticker="MSFT", price=350.0, composite_score=0.60, options_volume=2000, open_interest=8000, iv=0.25),
        CandidateFeatures(ticker="NVDA", price=600.0, composite_score=0.90, options_volume=5000, open_interest=15000, iv=0.50),
        CandidateFeatures(ticker="TSLA", price=250.0, composite_score=0.20, options_volume=4000, open_interest=12000, iv=0.70),
        CandidateFeatures(ticker="AMZN", price=185.0, composite_score=0.40, options_volume=1500, open_interest=6000, iv=0.35),
    ]


# 1
def test_output_contains_exactly_4_proposals(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    assert len(output.proposals) == 4


# 2
def test_all_four_strategy_types_present(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    types = {p["strategy_type"] for p in output.proposals}
    assert types == {st.value for st in StrategyType}


# 3
def test_each_proposal_has_ticker(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    for p in output.proposals:
        assert p["ticker"] != ""


# 4
def test_each_proposal_has_strike(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    for p in output.proposals:
        assert p["strike"] > 0


# 5
def test_each_proposal_has_expiry(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    for p in output.proposals:
        assert p["expiry"] is not None


# 6
def test_long_call_selects_highest_score(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    lc = next(p for p in output.proposals if p["strategy_type"] == StrategyType.LONG_CALL.value)
    assert lc["ticker"] == "NVDA"  # highest composite_score = 0.90


# 7
def test_long_put_selects_lowest_score(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    lp = next(p for p in output.proposals if p["strategy_type"] == StrategyType.LONG_PUT.value)
    assert lp["ticker"] == "TSLA"  # lowest composite_score = 0.20


# 8
def test_risk_reward_ratio_positive(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    for p in output.proposals:
        assert p["risk_reward_ratio"] > 0


# 9
def test_greeks_present_in_proposal(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    for p in output.proposals:
        assert "greeks" in p
        assert "delta" in p["greeks"]


# 10
def test_composite_score_in_proposal(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    for p in output.proposals:
        assert 0.0 <= p["composite_score"] <= 1.0


# 11
def test_empty_candidates_raises_value_error(agent) -> None:
    with pytest.raises(ValueError):
        run(agent.run(StrategyInput(candidates=[])))


# 12
def test_long_call_strike_above_price(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    lc = next(p for p in output.proposals if p["strategy_type"] == StrategyType.LONG_CALL.value)
    candidate = next(c for c in candidates if c.ticker == lc["ticker"])
    assert lc["strike"] > candidate.price  # 1.05× multiplier


# 13
def test_long_put_strike_below_price(agent, candidates) -> None:
    output = run(agent.run(StrategyInput(candidates=candidates)))
    lp = next(p for p in output.proposals if p["strategy_type"] == StrategyType.LONG_PUT.value)
    candidate = next(c for c in candidates if c.ticker == lp["ticker"])
    assert lp["strike"] < candidate.price  # 0.95× multiplier


# 14
def test_run_date_used_for_expiry(agent, candidates) -> None:
    run_date = date(2025, 1, 1)
    output = run(agent.run(StrategyInput(candidates=candidates, run_date=run_date)))
    for p in output.proposals:
        expiry = date.fromisoformat(p["expiry"])
        assert expiry > run_date
