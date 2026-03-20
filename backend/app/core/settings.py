from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = 'WIMC API'
    environment: str = 'development'
    database_url: str = 'postgresql+psycopg://user:pass@localhost:5432/wimc'
    storage_root: str = '/Volumes/AI/WIMC'
    bearer_secret: str = 'change-me'


settings = Settings()
