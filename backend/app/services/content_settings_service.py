import json
from datetime import datetime
from typing import Any, Dict, Optional
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting
from .app_copy_service import COPY_FIELD_KEYS, flatten_app_copy, get_app_copy, save_flat_app_copy
from .branding_service import BRANDING_FIELD_KEYS, get_branding, project_branding, save_branding
from .runtime_settings_service import RUNTIME_SETTINGS_FIELD_KEYS, get_runtime_settings, save_runtime_settings

CONTENT_SCHEDULE_KEY = 'content_publish_schedule'
CONTENT_SCHEDULE_TIME_FORMAT = '%Y-%m-%d %H:%M:%S'
CONTENT_TIMEZONE = ZoneInfo('Asia/Seoul')


def _now_local() -> datetime:
    return datetime.now(CONTENT_TIMEZONE)


def _format_local_datetime(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=CONTENT_TIMEZONE)
    return value.astimezone(CONTENT_TIMEZONE).strftime(CONTENT_SCHEDULE_TIME_FORMAT)


def _parse_local_datetime(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        parsed = datetime.strptime(value.strip(), CONTENT_SCHEDULE_TIME_FORMAT)
    except ValueError as exc:
        raise ValueError('publishAt must use YYYY-MM-DD HH:MM:SS') from exc
    return parsed.replace(tzinfo=CONTENT_TIMEZONE)


def _save_content_settings_now(db: OrmSession, payload: Dict[str, Any]) -> None:
    branding_payload = {
        key: value
        for key, value in payload.items()
        if key in BRANDING_FIELD_KEYS
    }
    branding = save_branding(db, branding_payload)

    copy_payload = {
        key: value
        for key, value in payload.items()
        if key in COPY_FIELD_KEYS
    }
    if copy_payload:
        save_flat_app_copy(db, copy_payload, branding=branding)

    runtime_payload = {
        key: value
        for key, value in payload.items()
        if key in RUNTIME_SETTINGS_FIELD_KEYS
    }
    if runtime_payload:
        save_runtime_settings(db, runtime_payload)


def _get_content_schedule_setting(db: OrmSession) -> Optional[AppSetting]:
    return db.get(AppSetting, CONTENT_SCHEDULE_KEY)


def get_content_schedule(db: OrmSession) -> Dict[str, Any]:
    setting = _get_content_schedule_setting(db)
    if setting is None:
        return {
            'pending': False,
            'publishAt': None,
            'updatedAt': None,
            'payload': None,
        }

    try:
        payload = json.loads(setting.value_json)
        if isinstance(payload, dict):
            return {
                'pending': bool(payload.get('publishAt')),
                'publishAt': payload.get('publishAt'),
                'updatedAt': payload.get('updatedAt'),
                'payload': payload.get('payload'),
            }
    except json.JSONDecodeError:
        pass

    return {
        'pending': False,
        'publishAt': None,
        'updatedAt': None,
        'payload': None,
    }


def _save_content_schedule(db: OrmSession, payload: Dict[str, Any], publish_at: datetime) -> Dict[str, Any]:
    scheduled_payload = {
        'publishAt': _format_local_datetime(publish_at),
        'updatedAt': _format_local_datetime(_now_local()),
        'payload': payload,
    }
    setting = _get_content_schedule_setting(db)
    if setting is None:
        setting = AppSetting(
            key=CONTENT_SCHEDULE_KEY,
            value_json=json.dumps(scheduled_payload, ensure_ascii=False),
            updated_at=datetime.utcnow(),
        )
        db.add(setting)
    else:
        setting.value_json = json.dumps(scheduled_payload, ensure_ascii=False)
        setting.updated_at = datetime.utcnow()
        db.add(setting)
    db.commit()
    return get_content_schedule(db)


def clear_content_schedule(db: OrmSession) -> None:
    setting = _get_content_schedule_setting(db)
    if setting is None:
        return
    db.delete(setting)
    db.commit()


def apply_due_content_schedule(db: OrmSession) -> bool:
    schedule = get_content_schedule(db)
    publish_at = _parse_local_datetime(schedule.get('publishAt'))
    payload = schedule.get('payload') if isinstance(schedule.get('payload'), dict) else None
    if not publish_at or not payload:
        return False
    if publish_at > _now_local():
        return False

    _save_content_settings_now(db, payload)
    clear_content_schedule(db)
    return True


def get_content_settings(db: OrmSession) -> Dict[str, Any]:
    apply_due_content_schedule(db)
    branding = get_branding(db)
    app_copy = get_app_copy(db, branding)
    runtime_settings = get_runtime_settings(db)
    content = project_branding(branding)
    content.update(flatten_app_copy(app_copy))
    content.update(runtime_settings)
    return content


def save_content_settings(db: OrmSession, payload: Dict[str, Any], publish_at: Optional[str] = None) -> Dict[str, Any]:
    publish_at_dt = _parse_local_datetime(publish_at)
    if publish_at_dt and publish_at_dt > _now_local():
        _save_content_schedule(db, payload, publish_at_dt)
        return get_content_settings(db)

    clear_content_schedule(db)
    _save_content_settings_now(db, payload)
    return get_content_settings(db)
