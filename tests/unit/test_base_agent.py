"""Unit tests for BaseAgent — 8 tests."""

from __future__ import annotations

import asyncio

import pytest
from agents.base import BaseAgent


class EchoAgent(BaseAgent[str, str]):
    """Minimal concrete agent that echoes input."""

    async def _run(self, input_data: str) -> str:
        return input_data


class SlowAgent(BaseAgent[float, str]):
    """Agent that sleeps for the given number of seconds."""

    async def _run(self, input_data: float) -> str:
        await asyncio.sleep(input_data)
        return "done"


# 1
def test_agent_name_stored() -> None:
    agent = EchoAgent(name="echo")
    assert agent.name == "echo"


# 2
async def test_agent_run_returns_output() -> None:
    agent = EchoAgent(name="echo")
    result = await agent.run("hello")
    assert result == "hello"


# 3
async def test_elapsed_seconds_returns_float_after_run() -> None:
    agent = EchoAgent(name="echo")
    await agent.run("x")
    assert isinstance(agent.elapsed_seconds, float)
    assert agent.elapsed_seconds >= 0.0


# 4
def test_elapsed_seconds_zero_before_run() -> None:
    agent = EchoAgent(name="echo")
    assert agent.elapsed_seconds == 0.0


# 5
async def test_agent_without_timeout_runs_freely() -> None:
    agent = EchoAgent(name="echo", timeout_seconds=None)
    result = await agent.run("no timeout")
    assert result == "no timeout"


# 6
async def test_agent_with_sufficient_timeout_completes() -> None:
    agent = SlowAgent(name="slow", timeout_seconds=5.0)
    result = await agent.run(0.01)
    assert result == "done"


# 7
async def test_agent_timeout_raises_asyncio_timeout_error() -> None:
    agent = SlowAgent(name="slow", timeout_seconds=0.01)
    with pytest.raises(asyncio.TimeoutError):
        await agent.run(10.0)


# 8
async def test_elapsed_seconds_reflects_actual_duration() -> None:
    agent = EchoAgent(name="echo", timeout_seconds=None)
    await agent.run("measure")
    # Should be tiny but non-negative
    assert agent.elapsed_seconds >= 0.0
    assert agent.elapsed_seconds < 5.0
