from typing import Any, Dict

from sqlalchemy.orm import Session as OrmSession

from .app_copy_service import COPY_FIELD_KEYS, flatten_app_copy, get_app_copy, save_flat_app_copy
from .branding_service import BRANDING_FIELD_KEYS, get_branding, project_branding, save_branding


def get_content_settings(db: OrmSession) -> Dict[str, Any]:
    branding = get_branding(db)
    app_copy = get_app_copy(db, branding)
    content = project_branding(branding)
    content.update(flatten_app_copy(app_copy))
    return content


def save_content_settings(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
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

    return get_content_settings(db)
