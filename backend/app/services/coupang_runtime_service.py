import json
from typing import Any, Dict

from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..db.models import AppSetting

COUPANG_RUNTIME_KEY = 'coupang_runtime'
_COUPANG_RUNTIME_HISTORY_LIMIT = 10
DEFAULT_COUPANG_RUNTIME: Dict[str, Any] = {
    'enabledOverride': None,
    'operatorNote': '',
    'recentChanges': [],
}


def _normalize_recent_changes(payload: Any) -> list[Dict[str, Any]]:
    if not isinstance(payload, list):
        return []

    normalized: list[Dict[str, Any]] = []
    for item in payload:
        if not isinstance(item, dict):
            continue
        changed_at = item.get('changedAt')
        config_source = item.get('configSource')
        operator_note = item.get('operatorNote')
        enabled_override = item.get('enabledOverride')
        effective_enabled = item.get('effectiveEnabled')

        if not isinstance(changed_at, str) or not changed_at.strip():
            continue
        if not isinstance(config_source, str) or not config_source.strip():
            config_source = 'env_default'
        if not isinstance(operator_note, str):
            operator_note = ''
        if enabled_override is not None and not isinstance(enabled_override, bool):
            enabled_override = None
        if not isinstance(effective_enabled, bool):
            effective_enabled = False

        normalized.append({
            'changedAt': changed_at.strip(),
            'configSource': config_source.strip(),
            'enabledOverride': enabled_override,
            'effectiveEnabled': effective_enabled,
            'operatorNote': operator_note.strip(),
        })

    return normalized[:_COUPANG_RUNTIME_HISTORY_LIMIT]


def _normalize_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    enabled_override = payload.get('enabledOverride')
    if enabled_override is not None and not isinstance(enabled_override, bool):
        enabled_override = None

    operator_note = payload.get('operatorNote')
    if not isinstance(operator_note, str):
        operator_note = ''

    return {
        'enabledOverride': enabled_override,
        'operatorNote': operator_note.strip(),
        'recentChanges': _normalize_recent_changes(payload.get('recentChanges')),
    }


def get_coupang_runtime(db: OrmSession) -> Dict[str, Any]:
    row = db.get(AppSetting, COUPANG_RUNTIME_KEY)
    if row is None:
        return dict(DEFAULT_COUPANG_RUNTIME)
    try:
        payload = json.loads(row.value_json or '{}') or {}
    except Exception:
        return dict(DEFAULT_COUPANG_RUNTIME)
    if not isinstance(payload, dict):
        return dict(DEFAULT_COUPANG_RUNTIME)
    normalized = _normalize_payload(payload)
    return normalized


def save_coupang_runtime(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
    normalized = _normalize_payload(payload)
    row = db.get(AppSetting, COUPANG_RUNTIME_KEY)
    previous = get_coupang_runtime(db)
    env_enabled = settings.coupang_partners_enabled
    effective_enabled = normalized['enabledOverride'] if isinstance(normalized['enabledOverride'], bool) else env_enabled
    config_source = 'admin_override' if isinstance(normalized['enabledOverride'], bool) else 'env_default'
    history_entry = {
        'changedAt': '',
        'configSource': config_source,
        'enabledOverride': normalized['enabledOverride'],
        'effectiveEnabled': effective_enabled,
        'operatorNote': normalized['operatorNote'],
    }
    existing_history = previous.get('recentChanges') if isinstance(previous.get('recentChanges'), list) else []
    normalized['recentChanges'] = [history_entry, *existing_history][: _COUPANG_RUNTIME_HISTORY_LIMIT]
    raw = json.dumps(normalized, ensure_ascii=False)
    if row is None:
        row = AppSetting(key=COUPANG_RUNTIME_KEY, value_json=raw)
    else:
        row.value_json = raw
    db.add(row)
    db.commit()
    db.refresh(row)
    updated_at = row.updated_at.isoformat() if row.updated_at else None
    normalized['recentChanges'][0]['changedAt'] = updated_at or ''
    row.value_json = json.dumps(normalized, ensure_ascii=False)
    db.add(row)
    db.commit()
    db.refresh(row)
    return {
        **normalized,
        'updatedAt': row.updated_at.isoformat() if row.updated_at else None,
    }


def get_coupang_runtime_status(db: OrmSession) -> Dict[str, Any]:
    runtime = get_coupang_runtime(db)
    row = db.get(AppSetting, COUPANG_RUNTIME_KEY)
    enabled_override = runtime.get('enabledOverride')
    env_enabled = settings.coupang_partners_enabled
    effective_enabled = enabled_override if isinstance(enabled_override, bool) else env_enabled
    access_key_configured = bool(settings.coupang_partners_access_key.strip())
    secret_key_configured = bool(settings.coupang_partners_secret_key.strip())
    return {
        'enabled': effective_enabled,
        'envEnabled': env_enabled,
        'enabledOverride': enabled_override,
        'configSource': 'admin_override' if isinstance(enabled_override, bool) else 'env_default',
        'accessKeyConfigured': access_key_configured,
        'secretKeyConfigured': secret_key_configured,
        'affiliateReady': bool(effective_enabled and access_key_configured and secret_key_configured),
        'operatorNote': runtime.get('operatorNote') or '',
        'recentChanges': runtime.get('recentChanges') or [],
        'updatedAt': row.updated_at.isoformat() if row and row.updated_at else None,
    }
