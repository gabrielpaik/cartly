from sqlalchemy import text

from .base import Base
from .models import (  # noqa: F401
    AdCampaign,
    AdClick,
    AdImpression,
    AdSlot,
    AdminDashboardSnapshot,
    AdminSession,
    AppEvent,
    AppSetting,
    PushCampaign,
    PushDevice,
    EmailAuthCode,
    Cart,
    CategoryOverride,
    CartItem,
    Receipt,
    ReceiptLineItem,
    ScanFailureLog,
    ScanFeedback,
    ScanJob,
    Session,
    User,
)
from .session import engine


def _run_runtime_migrations() -> None:
    statements = [
        "ALTER TABLE app_events ADD COLUMN IF NOT EXISTS client_timestamp TIMESTAMP NULL",
        "ALTER TABLE app_events ADD COLUMN IF NOT EXISTS device_platform VARCHAR(40) NULL",
        "ALTER TABLE app_events ADD COLUMN IF NOT EXISTS device_type VARCHAR(40) NULL",
        "ALTER TABLE app_events ADD COLUMN IF NOT EXISTS os_name VARCHAR(80) NULL",
        "ALTER TABLE app_events ADD COLUMN IF NOT EXISTS os_version VARCHAR(80) NULL",
        "ALTER TABLE app_events ADD COLUMN IF NOT EXISTS app_version VARCHAR(80) NULL",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT NULL",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMP NULL",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS guest_code VARCHAR(4) NULL",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS guest_key VARCHAR(120) NULL",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS last_device_platform VARCHAR(40) NULL",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS last_app_version VARCHAR(80) NULL",
        "ALTER TABLE carts ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP NULL",
        "ALTER TABLE carts ADD COLUMN IF NOT EXISTS retention_extension_count INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS merged_into_user_id VARCHAR(36) NULL",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS merged_at TIMESTAMP NULL",
        "ALTER TABLE carts ADD COLUMN IF NOT EXISTS source_cart_id VARCHAR(36) NULL",
        "ALTER TABLE carts ADD COLUMN IF NOT EXISTS saved_date DATE NULL",
        "ALTER TABLE carts ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP NULL",
        "ALTER TABLE cart_items ADD COLUMN IF NOT EXISTS original_name VARCHAR(255) NULL",
        "UPDATE carts SET saved_date = COALESCE(saved_date, DATE(created_at))",
        "ALTER TABLE carts ALTER COLUMN saved_date SET DEFAULT CURRENT_DATE",
        "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_guest_code ON users (guest_code) WHERE guest_code IS NOT NULL",
        "ALTER TABLE push_devices ADD COLUMN IF NOT EXISTS push_debug_json TEXT NULL",
        "CREATE INDEX IF NOT EXISTS ix_push_devices_install_id ON push_devices (install_id)",
        "CREATE INDEX IF NOT EXISTS ix_push_devices_user_id ON push_devices (user_id)",
        "CREATE UNIQUE INDEX IF NOT EXISTS uq_category_overrides_target ON category_overrides (target_type, target_id)",
        "CREATE INDEX IF NOT EXISTS ix_category_overrides_target_type ON category_overrides (target_type)",
    ]
    with engine.begin() as conn:
        for statement in statements:
            conn.execute(text(statement))


def init_db() -> None:
    Base.metadata.create_all(bind=engine)
    _run_runtime_migrations()
