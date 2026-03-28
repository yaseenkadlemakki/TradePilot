"""Options flow ingestor — unusual activity and sweeps via Unusual Whales."""

from __future__ import annotations

from typing import Any

from data_pipelines.ingestors.base import BaseIngestor


class OptionsFlowIngestor(BaseIngestor):
    """Fetch unusual options flow and sweep data from Unusual Whales.

    Requires ``UNUSUAL_WHALES_API_KEY`` in environment.  Scaffolded — returns
    empty list until the Unusual Whales client is wired in.
    """

    def __init__(self, api_key: str | None = None) -> None:
        super().__init__(name="OptionsFlow")
        self._api_key = api_key

    async def _fetch(self, tickers: list[str] | None = None, **kwargs: Any) -> list[dict[str, Any]]:
        self._log.info("options_flow.fetch", ticker_count=len(tickers) if tickers else 0)
        # Scaffolded: Unusual Whales client not yet wired.
        return []
