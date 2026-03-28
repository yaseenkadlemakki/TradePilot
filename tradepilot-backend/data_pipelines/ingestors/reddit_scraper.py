"""Reddit scraper ingestor — posts from WSB, r/options, r/stocks, r/investing."""

from __future__ import annotations

from typing import Any

from data_pipelines.ingestors.base import BaseIngestor

_DEFAULT_SUBREDDITS = ["wallstreetbets", "options", "stocks", "investing"]


class RedditScraperIngestor(BaseIngestor):
    """Fetch posts and comments from finance-related subreddits via the Reddit API.

    Requires ``REDDIT_CLIENT_ID`` and ``REDDIT_CLIENT_SECRET`` in environment.
    Scaffolded — returns empty list until the PRAW/Reddit client is wired in.
    """

    def __init__(self, client_id: str | None = None, client_secret: str | None = None) -> None:
        super().__init__(name="RedditScraper")
        self._client_id = client_id
        self._client_secret = client_secret

    async def _fetch(
        self,
        subreddits: list[str] | None = None,
        limit: int = 100,
        **kwargs: Any,
    ) -> list[dict[str, Any]]:
        subs = subreddits or _DEFAULT_SUBREDDITS
        self._log.info("reddit_scraper.fetch", subreddits=subs, limit=limit)
        # Scaffolded: Reddit client not yet wired.
        return []
