import json
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting

SMOKE_HISTORY_KEY = 'ops_smoke_history'
SMOKE_HISTORY_LIMIT = 12


DEFAULT_SMOKE_HISTORY: Dict[str, Any] = {
    'history': [],
}


def _normalize_result(item: Any) -> Optional[Dict[str, Any]]:
    if not isinstance(item, dict):
        return None

    key = item.get('key')
    label = item.get('label')
    url = item.get('url')
    status = item.get('status')
    ok = item.get('ok')
    duration_ms = item.get('durationMs')
    error = item.get('error')

    if not isinstance(key, str) or not key.strip():
        return None
    if not isinstance(label, str):
        label = key
    if not isinstance(url, str):
        url = ''
    if status is not None and not isinstance(status, int):
        status = None
    if not isinstance(ok, bool):
        ok = False
    if not isinstance(duration_ms, int):
        duration_ms = 0
    if not isinstance(error, str):
        error = ''

    return {
        'key': key.strip(),
        'label': label.strip(),
        'url': url.strip(),
        'status': status,
        'ok': ok,
        'durationMs': duration_ms,
        'error': error.strip(),
    }


def _normalize_history_entry(item: Any) -> Optional[Dict[str, Any]]:
    if not isinstance(item, dict):
        return None

    checked_at = item.get('checkedAt')
    ok = item.get('ok')
    failure_count = item.get('failureCount')
    results = item.get('results')

    if not isinstance(checked_at, str) or not checked_at.strip():
        return None
    if not isinstance(ok, bool):
        ok = False
    if not isinstance(failure_count, int):
        failure_count = 0

    normalized_results: List[Dict[str, Any]] = []
    if isinstance(results, list):
        for result in results:
            normalized = _normalize_result(result)
            if normalized is not None:
                normalized_results.append(normalized)

    return {
        'checkedAt': checked_at.strip(),
        'ok': ok,
        'failureCount': failure_count,
        'results': normalized_results,
    }


def _normalize_payload(payload: Any) -> Dict[str, Any]:
    if not isinstance(payload, dict):
        return dict(DEFAULT_SMOKE_HISTORY)

    history_items = payload.get('history') if isinstance(payload.get('history'), list) else []
    normalized_history = []
    for item in history_items:
        normalized = _normalize_history_entry(item)
        if normalized is not None:
            normalized_history.append(normalized)

    return {
        'history': normalized_history[:SMOKE_HISTORY_LIMIT],
    }


def get_smoke_history(db: OrmSession) -> Dict[str, Any]:
    row = db.get(AppSetting, SMOKE_HISTORY_KEY)
    if row is None:
        return dict(DEFAULT_SMOKE_HISTORY)
    try:
        payload = json.loads(row.value_json or '{}') or {}
    except Exception:
        return dict(DEFAULT_SMOKE_HISTORY)
    return _normalize_payload(payload)


def record_smoke_result(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
    checked_at = payload.get('checkedAt')
    ok = payload.get('ok')
    results = payload.get('results')

    if not isinstance(checked_at, str) or not checked_at.strip():
        checked_at = ''
    if not isinstance(ok, bool):
        ok = False

    normalized_results: List[Dict[str, Any]] = []
    if isinstance(results, list):
        for result in results:
            normalized = _normalize_result(result)
            if normalized is not None:
                normalized_results.append(normalized)

    entry = {
        'checkedAt': checked_at.strip(),
        'ok': ok,
        'failureCount': sum(1 for result in normalized_results if not result['ok']),
        'results': normalized_results,
    }

    previous = get_smoke_history(db)
    existing = previous.get('history') if isinstance(previous.get('history'), list) else []
    history = [entry, *existing]

    deduped: List[Dict[str, Any]] = []
    seen = set()
    for item in history:
        marker = item.get('checkedAt')
        if not isinstance(marker, str) or not marker:
            continue
        if marker in seen:
            continue
        seen.add(marker)
        deduped.append(item)
        if len(deduped) >= SMOKE_HISTORY_LIMIT:
            break

    normalized = {
        'history': deduped,
    }
    raw = json.dumps(normalized, ensure_ascii=False)

    row = db.get(AppSetting, SMOKE_HISTORY_KEY)
    if row is None:
        row = AppSetting(key=SMOKE_HISTORY_KEY, value_json=raw)
    else:
        row.value_json = raw
    db.add(row)
    db.commit()
    db.refresh(row)
    return normalized
