import json
from datetime import datetime
from typing import Any, Dict, Optional

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting

RUNTIME_SETTINGS_KEY = 'runtime_settings'
DEFAULT_RUNTIME_SETTINGS: Dict[str, Any] = {
    'receiptReminderDelayMinutes': 60,
}
RUNTIME_SETTINGS_FIELD_KEYS = tuple(DEFAULT_RUNTIME_SETTINGS.keys())


def _coerce_receipt_reminder_delay_minutes(value: Any) -> int:
    try:
        normalized = int(value)
    except (TypeError, ValueError):
        return DEFAULT_RUNTIME_SETTINGS['receiptReminderDelayMinutes']
    return max(1, normalized)


def normalize_runtime_settings(payload: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    source = payload if isinstance(payload, dict) else {}
    return {
        'receiptReminderDelayMinutes': _coerce_receipt_reminder_delay_minutes(
            source.get('receiptReminderDelayMinutes')
        ),
    }


def get_runtime_settings(db: OrmSession) -> Dict[str, Any]:
    setting = db.get(AppSetting, RUNTIME_SETTINGS_KEY)
    if setting is None:
        return dict(DEFAULT_RUNTIME_SETTINGS)
    try:
        payload = json.loads(setting.value_json)
        if isinstance(payload, dict):
            return normalize_runtime_settings(payload)
    except json.JSONDecodeError:
        pass
    return dict(DEFAULT_RUNTIME_SETTINGS)


def save_runtime_settings(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
    current = get_runtime_settings(db)
    merged = dict(current)
    for key in RUNTIME_SETTINGS_FIELD_KEYS:
        if key in payload:
            merged[key] = payload[key]
    normalized = normalize_runtime_settings(merged)
    setting = db.get(AppSetting, RUNTIME_SETTINGS_KEY)
    if setting is None:
        setting = AppSetting(
            key=RUNTIME_SETTINGS_KEY,
            value_json=json.dumps(normalized, ensure_ascii=False),
            updated_at=datetime.utcnow(),
        )
        db.add(setting)
    else:
        setting.value_json = json.dumps(normalized, ensure_ascii=False)
        setting.updated_at = datetime.utcnow()
        db.add(setting)
    db.commit()
    db.refresh(setting)
    return normalized
