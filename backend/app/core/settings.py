from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = 'WIMC API'
    environment: str = 'development'
    database_url: str = 'postgresql+psycopg://localhost:5432/wimc'
    storage_root: str = '/Volumes/AI/WIMC'
    bearer_secret: str = 'change-me'
    api_base_url: str = 'http://127.0.0.1:8011'
    remote_scan_enabled: bool = True
    ads_enabled: bool = True


settings = Settings()
