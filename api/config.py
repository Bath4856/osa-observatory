from pathlib import Path
from pydantic_settings import BaseSettings

# Chemin absolu vers api/.env — évite de lire le .env racine du repo
_ENV_FILE = Path(__file__).parent / ".env"


class Settings(BaseSettings):
    APP_NAME: str = "OSA ISA API"
    APP_VERSION: str = "2.0.0-candidate"
    APP_ENV: str = "production"

    DB_HOST: str
    DB_PORT: int = 5432
    DB_NAME: str
    DB_USER: str
    DB_PASSWORD: str

    API_EXPERT_KEY: str = "change-me"
    CORS_ORIGINS: str = "*"

    model_config = {"env_file": str(_ENV_FILE), "env_file_encoding": "utf-8", "extra": "ignore"}


settings = Settings()
