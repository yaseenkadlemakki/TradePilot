from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Database
    timescale_url: str = "postgresql+asyncpg://tradepilot:password@localhost:5432/tradepilot"
    mongo_url: str = "mongodb://localhost:27017"
    redis_url: str = "redis://localhost:6379/0"

    # Kafka
    kafka_bootstrap_servers: str = "localhost:9092"

    # Market data
    polygon_api_key: str = ""
    alpaca_api_key: str = ""
    alpaca_secret_key: str = ""

    # Options flow
    unusual_whales_api_key: str = ""

    # Reddit
    reddit_client_id: str = ""
    reddit_client_secret: str = ""

    # News
    news_api_key: str = ""

    # LLM
    anthropic_api_key: str = ""

    # Auth
    jwt_secret: str = "change-me-to-a-long-random-string"

    # App
    app_version: str = "0.1.0"
    debug: bool = False


_settings: Settings | None = None


def get_settings() -> Settings:
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings
