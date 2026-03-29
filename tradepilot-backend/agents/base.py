from __future__ import annotations

import asyncio
import time
from abc import ABC, abstractmethod
from typing import Generic, TypeVar

import structlog

InputT = TypeVar("InputT")
OutputT = TypeVar("OutputT")


class AgentError(Exception):
    """Structured error raised when an agent fails."""

    def __init__(self, agent_name: str, message: str, cause: BaseException | None = None) -> None:
        self.agent_name = agent_name
        self.message = message
        # NOTE: do not store cause as an attribute; use `raise ... from exc` for exception chaining.
        super().__init__(f"[{agent_name}] {message}")


class BaseAgent(ABC, Generic[InputT, OutputT]):
    """Generic async agent with optional timeout."""

    def __init__(self, name: str, timeout_seconds: float | None = None) -> None:
        self.name = name
        self.timeout_seconds = timeout_seconds
        self._log = structlog.get_logger().bind(agent=name)

    async def run(self, input_data: InputT) -> OutputT:
        """Execute the agent, enforcing timeout if configured."""
        start = time.monotonic()
        self._log.info("agent.start")
        try:
            if self.timeout_seconds is not None:
                result = await asyncio.wait_for(self._run(input_data), timeout=self.timeout_seconds)
            else:
                result = await self._run(input_data)
            self._elapsed = time.monotonic() - start
            self._log.info("agent.complete", duration_seconds=round(self._elapsed, 3))
            return result
        except asyncio.TimeoutError as exc:
            self._elapsed = time.monotonic() - start
            self._log.error(
                "agent.timeout",
                duration_seconds=round(self._elapsed, 3),
                timeout_seconds=self.timeout_seconds,
            )
            raise AgentError(self.name, f"Timed out after {self.timeout_seconds}s") from exc
        except Exception as exc:
            self._elapsed = time.monotonic() - start
            self._log.error(
                "agent.error",
                duration_seconds=round(self._elapsed, 3),
                error=str(exc),
                exc_type=type(exc).__name__,
            )
            raise

    @abstractmethod
    async def _run(self, input_data: InputT) -> OutputT:
        """Override in subclasses to implement agent logic."""
        ...

    @property
    def elapsed_seconds(self) -> float:
        return getattr(self, "_elapsed", 0.0)
