from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "MIGO DRIVE API"
    environment: str = "development"

    jwt_secret_key: str = (
        "CHANGE_ME_IN_LOCAL_ENV_BEFORE_REAL_USE"
    )
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
