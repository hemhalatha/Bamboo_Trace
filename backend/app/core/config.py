from pathlib import Path
from urllib.parse import urlparse

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


BACKEND_DIR = Path(__file__).resolve().parents[2]
SUPPORTED_JWT_ALGORITHMS = {"HS256", "HS384", "HS512"}


class Settings(BaseSettings):
    database_url: str = Field(alias="DATABASE_URL")
    jwt_secret_key: str = Field(alias="JWT_SECRET_KEY")
    jwt_algorithm: str = Field(default="HS256", alias="JWT_ALGORITHM")
    app_env: str = Field(default="development", alias="APP_ENV")
    access_token_expire_minutes: int = Field(
        default=60, alias="ACCESS_TOKEN_EXPIRE_MINUTES"
    )
    allowed_origins: str = Field(default="*", alias="ALLOWED_ORIGINS")
    allowed_origin_regex: str | None = Field(
        default=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        alias="ALLOWED_ORIGIN_REGEX",
    )
    run_db_startup_tasks: bool = Field(default=True, alias="RUN_DB_STARTUP_TASKS")

    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @model_validator(mode="after")
    def validate_security_settings(self) -> "Settings":
        self.jwt_algorithm = self.jwt_algorithm.strip().upper()
        if self.jwt_algorithm not in SUPPORTED_JWT_ALGORITHMS:
            raise ValueError("JWT_ALGORITHM must be HS256, HS384, or HS512")

        if self.app_env.strip().lower() != "production":
            return self

        placeholder_secrets = {
            "change-this-to-a-long-random-production-secret",
            "changeme",
            "secret",
        }
        if (
            len(self.jwt_secret_key) < 32
            or self.jwt_secret_key.strip().lower() in placeholder_secrets
        ):
            raise ValueError(
                "JWT_SECRET_KEY must be a strong non-placeholder secret in production"
            )

        allowed_origins = self.cors_origins
        if self.allowed_origins.strip() == "*" or len(allowed_origins) != 1:
            raise ValueError(
                "Production ALLOWED_ORIGINS must contain exactly one frontend origin"
            )

        origin = allowed_origins[0]
        parsed_origin = urlparse(origin)
        if (
            parsed_origin.scheme != "https"
            or not parsed_origin.netloc
            or parsed_origin.username is not None
            or parsed_origin.password is not None
            or parsed_origin.query
            or parsed_origin.fragment
        ):
            raise ValueError(
                "Production ALLOWED_ORIGINS must be one HTTPS frontend origin"
            )
        if parsed_origin.hostname in {"localhost", "127.0.0.1", "0.0.0.0"}:
            raise ValueError("ALLOWED_ORIGINS cannot allow local origins in production")

        if self.cors_origin_regex is not None:
            raise ValueError("ALLOWED_ORIGIN_REGEX must be empty in production")

        if self.run_db_startup_tasks:
            raise ValueError("RUN_DB_STARTUP_TASKS must be false in production")

        return self

    @property
    def cors_origins(self) -> list[str]:
        if self.allowed_origins.strip() == "*":
            return []
        return [
            origin.strip().rstrip("/")
            for origin in self.allowed_origins.split(",")
            if origin.strip()
        ]

    @property
    def cors_origin_regex(self) -> str | None:
        value = (self.allowed_origin_regex or "").strip()
        return value or None


settings = Settings()
