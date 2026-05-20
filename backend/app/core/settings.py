from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = 'Cartly API'
    environment: str = 'development'
    database_url: str = 'postgresql+psycopg://localhost:5432/cartly'
    storage_root: str = '/Volumes/AI/Cartly'
    runtime_assets_root: str = '~/Library/Application Support/Cartly/assets'
    bearer_secret: str = 'change-me'
    admin_token: str = ''
    api_base_url: str = 'http://127.0.0.1:8011'
    coupang_partners_enabled: bool = False
    coupang_partners_access_key: str = ''
    coupang_partners_secret_key: str = ''
    naver_shopping_search_enabled: bool = False
    naver_shopping_client_id: str = ''
    naver_shopping_client_secret: str = ''
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
    push_enabled: bool = False
    push_provider: str = 'fcm'
    firebase_project_id: str = ''
    firebase_service_account_json: str = ''
    firebase_service_account_path: str = ''


settings = Settings()
