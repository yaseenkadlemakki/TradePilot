from __future__ import annotations

from datetime import date, datetime
from typing import Any

from config.constants import MarketRegime, StrategyType
from pydantic import BaseModel, Field


class Greeks(BaseModel):
    delta: float = 0.0
    gamma: float = 0.0
    theta: float = 0.0
    vega: float = 0.0


class TradeProposal(BaseModel):
    ticker: str
    strategy_type: StrategyType
    strike: float
    expiry: date
    entry_price: float
    stop_loss: float
    take_profit: float
    risk_reward_ratio: float
    greeks: Greeks = Field(default_factory=Greeks)
    composite_score: float = Field(ge=0.0, le=1.0)
    rationale: str = ""
    iv: float = 0.0
    volume: int = 0
    open_interest: int = 0


class RiskWarning(BaseModel):
    level: str  # "soft" | "hard"
    message: str


class ValidatedProposal(BaseModel):
    proposal: TradeProposal
    warnings: list[RiskWarning] = Field(default_factory=list)
    passed: bool = True


class DailyRecommendations(BaseModel):
    run_date: date
    generated_at: datetime
    market_regime: MarketRegime = MarketRegime.NEUTRAL
    recommendations: list[ValidatedProposal] = Field(default_factory=list)
    pipeline_duration_seconds: float = 0.0
    metadata: dict[str, Any] = Field(default_factory=dict)


class RecommendationSummary(BaseModel):
    id: str
    run_date: date
    ticker: str
    strategy_type: StrategyType
    composite_score: float
    rationale: str = ""


class PerformanceMetrics(BaseModel):
    total_recommendations: int = 0
    win_rate: float = 0.0
    avg_return: float = 0.0
    sharpe_ratio: float = 0.0
