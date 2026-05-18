import json
from datetime import datetime
from typing import Any, Dict

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting

BRANDING_KEY = 'branding'
DEFAULT_LOGO_IMAGE_URL = 'https://scan-api.seoa-nas.com/assets/branding/cartly_logo_vectorized.svg'
DEFAULT_SPLASH_IMAGE_URL = 'https://scan-api.seoa-nas.com/assets/branding/cartly_splash_default.png'
DEFAULT_BRANDING: Dict[str, Any] = {
    'logoType': 'image',
    'logoText': 'Cartly',
    'logoImageUrl': DEFAULT_LOGO_IMAGE_URL,
    'splashImageUrl': DEFAULT_SPLASH_IMAGE_URL,
    'loginHeroImageUrl': None,
    'homeTabLabel': '홈',
    'helpTabLabel': '탐색',
    'myTabLabel': '마이페이지',
}
BRANDING_FIELD_KEYS = tuple(DEFAULT_BRANDING.keys())


def _normalize_branding_value(key: str, value: Any) -> Any:
    if key == 'loginHeroImageUrl':
        if isinstance(value, str):
            trimmed = value.strip()
            return trimmed or None
        return None

    default = DEFAULT_BRANDING[key]
    if value is None:
        return default
    if isinstance(value, str):
        trimmed = value.strip()
        return trimmed or default
    return value


def project_branding(payload: Dict[str, Any]) -> Dict[str, Any]:
    return {
        key: _normalize_branding_value(key, payload.get(key))
        for key in BRANDING_FIELD_KEYS
    }


def get_branding(db: OrmSession) -> Dict[str, Any]:
    setting = db.get(AppSetting, BRANDING_KEY)
    if setting is None:
        return dict(DEFAULT_BRANDING)
    try:
        payload = json.loads(setting.value_json)
        if isinstance(payload, dict):
            return project_branding(payload)
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
