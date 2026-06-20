import pytest
from pydantic import ValidationError

from app.core.config import Settings


def production_settings(**overrides: object) -> Settings:
    values = {
        "DATABASE_URL": "sqlite:///./config-test.db",
        "JWT_SECRET_KEY": "production-secret-with-enough-entropy-for-tests",
        "APP_ENV": "production",
        "ALLOWED_ORIGINS": "https://app.example.com",
        "ALLOWED_ORIGIN_REGEX": None,
        "RUN_DB_STARTUP_TASKS": False,
    }
    values.update(overrides)
    return Settings(**values)


def test_production_rejects_placeholder_jwt_secret() -> None:
    with pytest.raises(ValidationError):
        production_settings(
            JWT_SECRET_KEY="change-this-to-a-long-random-production-secret",
        )


def test_production_rejects_short_jwt_secret() -> None:
    with pytest.raises(ValidationError):
        production_settings(JWT_SECRET_KEY="short")


def test_production_rejects_wildcard_cors() -> None:
    with pytest.raises(ValidationError):
        production_settings(ALLOWED_ORIGINS="*")


def test_production_rejects_localhost_cors_origin() -> None:
    with pytest.raises(ValidationError):
        production_settings(ALLOWED_ORIGINS="http://localhost:3000")


def test_production_rejects_non_https_cors_origin() -> None:
    with pytest.raises(ValidationError):
        production_settings(ALLOWED_ORIGINS="http://app.example.com")


def test_production_rejects_localhost_cors_regex() -> None:
    with pytest.raises(ValidationError):
        production_settings(
            ALLOWED_ORIGIN_REGEX=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        )


def test_production_rejects_any_cors_regex() -> None:
    with pytest.raises(ValidationError):
        production_settings(
            ALLOWED_ORIGIN_REGEX=r"^https://.*\.example\.com$",
        )


def test_production_allows_only_one_frontend_origin() -> None:
    with pytest.raises(ValidationError):
        production_settings(
            ALLOWED_ORIGINS="https://app.example.com,https://admin.example.com",
        )


def test_production_rejects_automatic_database_startup_tasks() -> None:
    with pytest.raises(ValidationError):
        production_settings(RUN_DB_STARTUP_TASKS=True)


def test_rejects_unsupported_jwt_algorithm() -> None:
    with pytest.raises(ValidationError):
        production_settings(JWT_ALGORITHM="none")


