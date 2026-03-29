"""Market data ingestor — OHLCV bars, Greeks, IV, and bid/ask via Polygon.io."""

from __future__ import annotations

from typing import Any

from data_pipelines.ingestors.base import BaseIngestor


class MarketDataIngestor(BaseIngestor):
    """Fetch market prices and options chains from Polygon.io.

    Requires ``POLYGON_API_KEY`` in environment.  Scaffolded — returns empty
    list until the Polygon client is wired in.
    """

    def __init__(self, api_key: str | None = None) -> None:
        super().__init__(name="MarketData")
        self._api_key = api_key

    async def _fetch(self, tickers: list[str] | None = None, **kwargs: Any) -> list[dict[str, Any]]:
        self._log.info("market_data.fetch", ticker_count=len(tickers) if tickers else 0)
        # Scaffolded: Polygon client not yet wired.
        return []
