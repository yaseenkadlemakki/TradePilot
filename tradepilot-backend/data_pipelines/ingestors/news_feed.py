"""News feed ingestor — headlines and full articles via NewsAPI."""

from __future__ import annotations

from typing import Any

from data_pipelines.ingestors.base import BaseIngestor


class NewsFeedIngestor(BaseIngestor):
    """Fetch financial news headlines and article text from NewsAPI.

    Requires ``NEWS_API_KEY`` in environment.  Scaffolded — returns empty
    list until the NewsAPI client is wired in.
    """

    def __init__(self, api_key: str | None = None) -> None:
        super().__init__(name="NewsFeed")
        self._api_key = api_key

    async def _fetch(self, query: str | None = None, **kwargs: Any) -> list[dict[str, Any]]:
        self._log.info("news_feed.fetch", query=query)
        # Scaffolded: NewsAPI client not yet wired.
        return []
