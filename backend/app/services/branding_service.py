import json
from datetime import datetime
from typing import Any, Dict

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting

BRANDING_KEY = 'branding'
DEFAULT_BRANDING: Dict[str, Any] = {
    'logoType': 'text',
    'logoText': 'Cartly',
    'logoImageUrl': None,
    'splashImageUrl': None,
    'loginHeroImageUrl': None,
    'homeTabLabel': 'Home',
    'helpTabLabel': '도움',
    'savedTabLabel': 'Saved',
    'myTabLabel': 'My',
}
BRANDING_FIELD_KEYS = tuple(DEFAULT_BRANDING.keys())


def project_branding(payload: Dict[str, Any]) -> Dict[str, Any]:
    return {
        key: payload.get(key, DEFAULT_BRANDING[key])
        for key in BRANDING_FIELD_KEYS
    }


def get_branding(db: OrmSession) -> Dict[str, Any]:
    setting = db.get(AppSetting, BRANDING_KEY)
    if setting is None:
        return dict(DEFAULT_BRANDING)
    try:
        payload = json.loads(setting.value_json)
        if isinstance(payload, dict):
            merged = dict(DEFAULT_BRANDING)
            merged.update(payload)
            return merged
    except json.JSONDecodeError:
        pass
    return dict(DEFAULT_BRANDING)


def save_branding(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
    merged = project_branding(payload)
    setting = db.get(AppSetting, BRANDING_KEY)
    if setting is None:
        setting = AppSetting(
            key=BRANDING_KEY,
            value_json=json.dumps(merged, ensure_ascii=False),
            updated_at=datetime.utcnow(),
        )
        db.add(setting)
    else:
        setting.value_json = json.dumps(merged, ensure_ascii=False)
        setting.updated_at = datetime.utcnow()
        db.add(setting)
    db.commit()
    db.refresh(setting)
    return merged
