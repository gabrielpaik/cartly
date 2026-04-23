from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = 'Cartly API'
    environment: str = 'development'
    database_url: str = 'postgresql+psycopg://localhost:5432/wimc'
    storage_root: str = '/Volumes/AI/WIMC'
    runtime_assets_root: str = '~/Library/Application Support/WIMC/assets'
    bearer_secret: str = 'change-me'
    admin_token: str = ''
    api_base_url: str = 'http://127.0.0.1:8011'
    remote_scan_enabled: bool = True
    ads_enabled: bool = True
    openclaw_scan_command: str = ''
    openclaw_scan_timeout_seconds: int = 90
    # Preferred receipt-analysis settings
    openclaw_receipt_analysis_command: str = ''
    openclaw_receipt_analysis_timeout_seconds: int = 120
    # Legacy compatibility aliases
    openclaw_receipt_command: str = ''
    openclaw_receipt_timeout_seconds: int = 90
    openclaw_receipt_scan_command: str = ''
    openclaw_receipt_scan_timeout_seconds: int = 120
    smtp_host: str = 'smtp.gmail.com'
    smtp_port: int = 587
    smtp_username: str = ''
    smtp_password: str = ''
    smtp_from_email: str = ''
    smtp_use_ssl: bool = False
    smtp_use_starttls: bool = True


settings = Settings()
