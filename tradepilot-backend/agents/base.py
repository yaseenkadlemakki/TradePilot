"""Base class for all async pipeline agents."""

from __future__ import annotations

import asyncio
import time
from abc import ABC, abstractmethod
from typing import Generic, TypeVar

InputT = TypeVar("InputT")
OutputT = TypeVar("OutputT")


class BaseAgent(ABC, Generic[InputT, OutputT]):
    """Generic async agent with optional timeout.

    Subclasses must implement ``_run`` with the actual agent logic.
    Call ``run`` to execute with optional timeout enforcement.
    """

    def __init__(self, name: str, timeout_seconds: float | None = None) -> None:
        """Initialise the agent.

        Args:
            name: Human-readable identifier used in logs and traces.
            timeout_seconds: If set, ``run`` will raise ``asyncio.TimeoutError``
                after this many seconds.
        """
        self.name = name
        self.timeout_seconds = timeout_seconds

    async def run(self, input_data: InputT) -> OutputT:
        """Execute the agent, enforcing timeout if configured.

        Args:
            input_data: Typed input passed to ``_run``.

        Returns:
            The typed output produced by ``_run``.

        Raises:
            asyncio.TimeoutError: If execution exceeds ``timeout_seconds``.
        """
        start = time.monotonic()
        if self.timeout_seconds is not None:
            result = await asyncio.wait_for(self._run(input_data), timeout=self.timeout_seconds)
        else:
            result = await self._run(input_data)
        self._elapsed = time.monotonic() - start
        return result

    @abstractmethod
    async def _run(self, input_data: InputT) -> OutputT:
        """Override in subclasses to implement agent logic.

        Args:
            input_data: Typed input for this agent.

        Returns:
            Typed output from this agent.
        """
        ...

    @property
    def elapsed_seconds(self) -> float:
        """Wall-clock seconds consumed by the last ``run`` call, or 0.0 if not yet run."""
        return getattr(self, "_elapsed", 0.0)
