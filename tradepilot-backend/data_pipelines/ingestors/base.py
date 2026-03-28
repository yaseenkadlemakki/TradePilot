"""Base ingestor — defines the contract and shared logging for all ingestors."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any

import structlog


class BaseIngestor(ABC):
    """Abstract base for all data ingestors.

    Subclasses implement ``_fetch`` and get structured logging and error
    handling for free via the public ``fetch`` method.
    """

    def __init__(self, name: str) -> None:
        self.name = name
        self._log = structlog.get_logger().bind(ingestor=name)

    async def fetch(self, **kwargs: Any) -> list[dict[str, Any]]:
        """Fetch records, logging start/complete/error with record counts."""
        self._log.info("ingestor.fetch_start", kwargs=kwargs)
        try:
            records = await self._fetch(**kwargs)
            self._log.info("ingestor.fetch_complete", record_count=len(records))
            return records
        except Exception as exc:
            self._log.error("ingestor.fetch_error", error=str(exc), exc_type=type(exc).__name__)
            raise

    @abstractmethod
    async def _fetch(self, **kwargs: Any) -> list[dict[str, Any]]:
        """Implement data retrieval logic in subclasses."""
        ...
