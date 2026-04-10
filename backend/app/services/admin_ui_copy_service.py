import json
from typing import Dict

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting

ADMIN_UI_COPY_KEY = 'admin_ui_copy'


def get_admin_ui_copy(db: OrmSession) -> Dict[str, str]:
    row = db.get(AppSetting, ADMIN_UI_COPY_KEY)
    if row is None:
        return {}
    try:
        payload = json.loads(row.value_json or '{}') or {}
    except Exception:
        return {}
    if not isinstance(payload, dict):
        return {}
    result: Dict[str, str] = {}
    for key, value in payload.items():
        if isinstance(key, str) and isinstance(value, str):
            result[key] = value
    return result


def save_admin_ui_copy(db: OrmSession, values: Dict[str, str]) -> Dict[str, str]:
    normalized: Dict[str, str] = {}
    for key, value in values.items():
        if not isinstance(key, str):
            continue
        if not isinstance(value, str):
            continue
        normalized[key] = value

    row = db.get(AppSetting, ADMIN_UI_COPY_KEY)
    payload = json.dumps(normalized, ensure_ascii=False)
    if row is None:
        row = AppSetting(key=ADMIN_UI_COPY_KEY, value_json=payload)
    else:
        row.value_json = payload
    db.add(row)
    db.commit()
    db.refresh(row)
    return normalized
