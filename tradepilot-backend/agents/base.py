from __future__ import annotations

import asyncio
import time
from abc import ABC, abstractmethod
from typing import Generic, TypeVar

InputT = TypeVar("InputT")
OutputT = TypeVar("OutputT")


class BaseAgent(ABC, Generic[InputT, OutputT]):
    """Generic async agent with optional timeout."""

    def __init__(self, name: str, timeout_seconds: float | None = None) -> None:
        self.name = name
        self.timeout_seconds = timeout_seconds

    async def run(self, input_data: InputT) -> OutputT:
        """Execute the agent, enforcing timeout if configured."""
        start = time.monotonic()
        if self.timeout_seconds is not None:
            result = await asyncio.wait_for(self._run(input_data), timeout=self.timeout_seconds)
        else:
            result = await self._run(input_data)
        self._elapsed = time.monotonic() - start
        return result

    @abstractmethod
    async def _run(self, input_data: InputT) -> OutputT:
        """Override in subclasses to implement agent logic."""
        ...

    @property
    def elapsed_seconds(self) -> float:
        return getattr(self, "_elapsed", 0.0)
