from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


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

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @model_validator(mode="after")
    def validate_production_security(self) -> "Settings":
        if self.app_env.strip().lower() != "production":
            return self

        if (
            len(self.jwt_secret_key) < 32
            or self.jwt_secret_key == "change-this-to-a-long-random-production-secret"
        ):
            raise ValueError(
                "JWT_SECRET_KEY must be a strong non-placeholder secret in production"
            )

        if self.allowed_origins.strip() == "*":
            raise ValueError("ALLOWED_ORIGINS cannot be '*' in production")

        if self.allowed_origin_regex:
            lowered_regex = self.allowed_origin_regex.lower()
            if "localhost" in lowered_regex or "127" in lowered_regex:
                raise ValueError(
                    "ALLOWED_ORIGIN_REGEX cannot allow local origins in production"
                )

        return self

    @property
    def cors_origins(self) -> list[str]:
        if self.allowed_origins == "*":
            return []
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin]


settings = Settings()
