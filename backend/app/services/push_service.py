from __future__ import annotations

import json
from datetime import datetime
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import firebase_admin
from firebase_admin import credentials, messaging
from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..db.models import PushCampaign, PushDevice, User
from .user_region_service import normalize_region_keys, resolve_user_ids_for_region_segment


def get_push_runtime_status(db: OrmSession) -> Dict[str, Any]:
    blockers: List[str] = []
    if not settings.push_enabled:
        blockers.append('push_enabled=false')
    if settings.push_provider.strip().lower() != 'fcm':
        blockers.append('unsupported provider')
    if not settings.firebase_project_id.strip():
        blockers.append('firebase_project_id missing')
    if not settings.firebase_service_account_json.strip() and not settings.firebase_service_account_path.strip():
        blockers.append('firebase service account missing')

    total_devices = db.query(PushDevice).count()
    active_devices = db.query(PushDevice).filter(PushDevice.status == 'active').count()
    invalid_devices = db.query(PushDevice).filter(PushDevice.status == 'invalid').count()
    token_ready_devices = (
        db.query(PushDevice)
        .filter(PushDevice.status == 'active', PushDevice.push_token.is_not(None))
        .count()
    )

    return {
        'enabled': settings.push_enabled,
        'provider': settings.push_provider,
        'ready': len(blockers) == 0,
        'blockers': blockers,
        'firebaseProjectId': settings.firebase_project_id or None,
        'devices': {
            'total': total_devices,
            'active': active_devices,
            'invalid': invalid_devices,
            'tokenReady': token_ready_devices,
        },
    }


def _normalize_region_segment(segment: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not isinstance(segment, dict):
        return None
    mode = str(segment.get('mode') or 'none').strip().lower()
    if mode not in {'none', 'recent', 'frequent', 'primary'} or mode == 'none':
        return None
    region_keys = normalize_region_keys(segment.get('regionKeys'))
    if not region_keys:
        return None
    normalized: Dict[str, Any] = {
        'mode': mode,
        'regionKeys': region_keys,
    }
    if mode == 'recent':
        normalized['recentWithinDays'] = max(1, int(segment.get('recentWithinDays') or 30))
    if mode == 'frequent':
        normalized['minVisits'] = max(1, int(segment.get('minVisits') or 3))
    return normalized


def register_push_device(
    db: OrmSession,
    *,
    user_id: Optional[str],
    install_id: str,
    platform: str,
    push_provider: Optional[str],
    push_token: Optional[str],
    notifications_enabled: bool,
    app_version: Optional[str],
    locale: Optional[str],
    debug_info: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    normalized_install_id = install_id.strip()
    normalized_platform = (platform or 'unknown').strip() or 'unknown'
    normalized_provider = (push_provider or '').strip() or None
    normalized_token = (push_token or '').strip() or None
    normalized_debug_info = debug_info or None

    existing = db.scalar(
        select(PushDevice).where(
            PushDevice.install_id == normalized_install_id,
            PushDevice.platform == normalized_platform,
        )
    )
    if existing is None and normalized_token:
        existing = db.scalar(select(PushDevice).where(PushDevice.push_token == normalized_token))

    if existing is None:
        existing = PushDevice(
            user_id=user_id,
            install_id=normalized_install_id,
            platform=normalized_platform,
            push_provider=normalized_provider,
            push_token=normalized_token,
            notifications_enabled=notifications_enabled,
            status='active',
            app_version=(app_version or '').strip() or None,
            locale=(locale or '').strip() or None,
            push_debug_json=json.dumps(normalized_debug_info, ensure_ascii=False) if normalized_debug_info else None,
            last_registered_at=datetime.utcnow(),
            last_seen_at=datetime.utcnow(),
        )
        db.add(existing)
    else:
        existing.user_id = user_id or existing.user_id
        existing.install_id = normalized_install_id
        existing.platform = normalized_platform
        existing.push_provider = normalized_provider
        existing.push_token = normalized_token or existing.push_token
        existing.notifications_enabled = notifications_enabled
        existing.app_version = (app_version or '').strip() or existing.app_version
        existing.locale = (locale or '').strip() or existing.locale
        existing.push_debug_json = json.dumps(normalized_debug_info, ensure_ascii=False) if normalized_debug_info else existing.push_debug_json
        existing.status = 'active'
        existing.last_registered_at = datetime.utcnow()
        existing.last_seen_at = datetime.utcnow()
        db.add(existing)

    db.commit()
    db.refresh(existing)
    return serialize_push_device(existing)


def list_push_devices(db: OrmSession, *, limit: int = 50) -> List[Dict[str, Any]]:
    rows = db.scalars(
        select(PushDevice).order_by(PushDevice.updated_at.desc()).limit(max(1, min(limit, 200)))
    ).all()
    return [serialize_push_device(row) for row in rows]


def list_push_campaigns(db: OrmSession, *, limit: int = 20) -> List[Dict[str, Any]]:
    rows = db.scalars(
        select(PushCampaign).order_by(PushCampaign.created_at.desc()).limit(max(1, min(limit, 100)))
    ).all()
    return [serialize_push_campaign(row) for row in rows]


def create_push_campaign(
    db: OrmSession,
    *,
    kind: str,
    audience: str,
    title: str,
    message: str,
    target_tab: Optional[str],
    target_url: Optional[str],
    requested_by: Optional[str],
    requested_by_source: Optional[str],
    explicit_audience: Optional[List[Dict[str, Any]]] = None,
    segment: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    runtime = get_push_runtime_status(db)
    status = 'queued' if runtime['ready'] else 'blocked'
    error_message = None if runtime['ready'] else '; '.join(runtime['blockers'])

    normalized_explicit_audience = _normalize_explicit_audience_entries(explicit_audience)
    normalized_segment = _normalize_region_segment(segment)

    row = PushCampaign(
        kind=kind,
        audience='upload' if audience == 'upload' else audience,
        status=status,
        title=title.strip(),
        message=message.strip(),
        target_tab=(target_tab or '').strip() or None,
        target_url=(target_url or '').strip() or None,
        requested_by=(requested_by or '').strip() or None,
        requested_by_source=(requested_by_source or '').strip() or None,
        segment_json=json.dumps(normalized_segment, ensure_ascii=False) if normalized_segment else None,
        delivery_provider=settings.push_provider if runtime['ready'] else None,
        error_message=error_message,
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    if runtime['ready']:
        try:
            result = _send_campaign_now(db, row, explicit_audience=normalized_explicit_audience, segment=normalized_segment)
        except Exception as error:
            row.status = 'failed'
            row.error_message = str(error)
            row.updated_at = datetime.utcnow()
            db.add(row)
            db.commit()
            db.refresh(row)
            return {
                'campaign': serialize_push_campaign(row),
                'runtime': runtime,
                'delivery': {'sentCount': 0, 'failureCount': 0, 'status': 'failed'},
            }
        db.refresh(row)
        return {
            'campaign': serialize_push_campaign(row),
            'runtime': runtime,
            'delivery': result,
        }

    return {
        'campaign': serialize_push_campaign(row),
        'runtime': runtime,
    }


@lru_cache(maxsize=1)
def _firebase_app() -> firebase_admin.App:
    app = firebase_admin.get_app() if firebase_admin._apps else None
    if app is not None:
        return app

    if settings.firebase_service_account_json.strip():
        info = json.loads(settings.firebase_service_account_json)
        cred = credentials.Certificate(info)
    elif settings.firebase_service_account_path.strip():
        cred = credentials.Certificate(Path(settings.firebase_service_account_path.strip()))
    else:
        raise RuntimeError('firebase service account missing')

    options = {}
    if settings.firebase_project_id.strip():
        options['projectId'] = settings.firebase_project_id.strip()

    return firebase_admin.initialize_app(cred, options or None)


def _normalize_explicit_audience_entries(entries: Optional[List[Dict[str, Any]]]) -> List[Dict[str, Optional[str]]]:
    normalized: List[Dict[str, Optional[str]]] = []
    seen = set()
    for entry in entries or []:
        user_id = str(entry.get('userId') or '').strip() or None
        install_id = str(entry.get('installId') or '').strip() or None
        name = str(entry.get('name') or '').strip() or None
        memo = str(entry.get('memo') or '').strip() or None
        if not user_id and not install_id:
            continue
        key = (user_id or '', install_id or '')
        if key in seen:
            continue
        seen.add(key)
        normalized.append({'userId': user_id, 'installId': install_id, 'name': name, 'memo': memo})
    return normalized



def _candidate_device_rows_for_entry(db: OrmSession, entry: Dict[str, Optional[str]]) -> List[Tuple[PushDevice, Optional[User]]]:
    rows: List[Tuple[PushDevice, Optional[User]]] = []
    seen = set()

    def append(query_rows: List[Tuple[PushDevice, Optional[User]]]):
        for device, user in query_rows:
            if device.id in seen:
                continue
            seen.add(device.id)
            rows.append((device, user))

    install_id = entry.get('installId')
    user_id = entry.get('userId')
    if install_id:
        append(
            db.query(PushDevice, User)
            .outerjoin(User, PushDevice.user_id == User.id)
            .filter(PushDevice.install_id == install_id)
            .all()
        )
    if user_id:
        append(
            db.query(PushDevice, User)
            .outerjoin(User, PushDevice.user_id == User.id)
            .filter(PushDevice.user_id == user_id)
            .all()
        )
    return rows



def _device_issue_code(device: PushDevice) -> str:
    if device.status != 'active':
        return 'invalid' if device.status == 'invalid' else 'inactive'
    if not (device.push_token or '').strip():
        return 'token_missing'
    if not device.notifications_enabled:
        return 'notifications_off'
    return 'ready'



def preview_push_audience(db: OrmSession, entries: Optional[List[Dict[str, Any]]]) -> Dict[str, Any]:
    normalized = _normalize_explicit_audience_entries(entries)
    summary = {
        'uploadedRows': len(normalized),
        'matchedRows': 0,
        'readyRows': 0,
        'matchedDevices': 0,
        'readyDevices': 0,
        'notFoundRows': 0,
        'tokenMissingRows': 0,
        'notificationsOffRows': 0,
        'invalidRows': 0,
        'inactiveRows': 0,
    }
    preview_rows: List[Dict[str, Any]] = []
    matched_device_ids = set()
    ready_device_ids = set()

    for entry in normalized:
        rows = _candidate_device_rows_for_entry(db, entry)
        ready_rows = [(device, user) for device, user in rows if _device_issue_code(device) == 'ready']
        for device, _ in rows:
            matched_device_ids.add(device.id)
        for device, _ in ready_rows:
            ready_device_ids.add(device.id)

        if not rows:
            issue = 'not_found'
            summary['notFoundRows'] += 1
        elif ready_rows:
            issue = 'ready'
            summary['matchedRows'] += 1
            summary['readyRows'] += 1
        else:
            summary['matchedRows'] += 1
            issue_codes = {_device_issue_code(device) for device, _ in rows}
            if 'invalid' in issue_codes:
                issue = 'invalid'
                summary['invalidRows'] += 1
            elif 'notifications_off' in issue_codes:
                issue = 'notifications_off'
                summary['notificationsOffRows'] += 1
            elif 'token_missing' in issue_codes:
                issue = 'token_missing'
                summary['tokenMissingRows'] += 1
            else:
                issue = 'inactive'
                summary['inactiveRows'] += 1

        preview_rows.append(
            {
                'userId': entry.get('userId'),
                'installId': entry.get('installId'),
                'name': entry.get('name'),
                'memo': entry.get('memo'),
                'issue': issue,
                'matchedDeviceCount': len(rows),
                'readyDeviceCount': len(ready_rows),
                'platforms': sorted({device.platform for device, _ in rows if (device.platform or '').strip()}),
                'lastSeenAt': max((device.last_seen_at for device, _ in rows if device.last_seen_at), default=None),
            }
        )

    summary['matchedDevices'] = len(matched_device_ids)
    summary['readyDevices'] = len(ready_device_ids)
    return {
        'summary': summary,
        'rows': [
            {
                **row,
                'lastSeenAt': row['lastSeenAt'].isoformat() if row['lastSeenAt'] else None,
            }
            for row in preview_rows[:50]
        ],
    }



def preview_push_segment(
    db: OrmSession,
    *,
    audience: str,
    segment: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    normalized_segment = _normalize_region_segment(segment)
    rows = _eligible_device_rows(db, audience, segment=normalized_segment)
    user_ids = {user.id for _, user in rows if user is not None}
    return {
        'audience': audience,
        'segment': normalized_segment,
        'summary': {
            'readyDeviceCount': len({device.id for device, _ in rows}),
            'readyUserCount': len(user_ids),
        },
    }


def _eligible_device_rows(
    db: OrmSession,
    audience: str,
    *,
    explicit_audience: Optional[List[Dict[str, Any]]] = None,
    segment: Optional[Dict[str, Any]] = None,
) -> List[Tuple[PushDevice, Optional[User]]]:
    rows = db.query(PushDevice, User).outerjoin(User, PushDevice.user_id == User.id).filter(
        PushDevice.status == 'active',
        PushDevice.notifications_enabled.is_(True),
        PushDevice.push_token.is_not(None),
    ).all()

    if audience == 'upload':
        selected: List[Tuple[PushDevice, Optional[User]]] = []
        seen = set()
        for entry in _normalize_explicit_audience_entries(explicit_audience):
            for device, user in _candidate_device_rows_for_entry(db, entry):
                if _device_issue_code(device) != 'ready' or device.id in seen:
                    continue
                seen.add(device.id)
                selected.append((device, user))
        rows = selected
    elif audience == 'members':
        rows = [row for row in rows if row[1] is not None and not row[1].is_guest]
    elif audience == 'guests':
        rows = [row for row in rows if row[1] is not None and row[1].is_guest]

    normalized_segment = _normalize_region_segment(segment)
    if normalized_segment:
        candidate_user_ids = {user.id for _, user in rows if user is not None}
        matched_user_ids = resolve_user_ids_for_region_segment(
            db,
            mode=str(normalized_segment.get('mode') or 'none'),
            region_keys=normalized_segment.get('regionKeys'),
            recent_within_days=normalized_segment.get('recentWithinDays'),
            min_visits=normalized_segment.get('minVisits'),
            candidate_user_ids=candidate_user_ids,
        ) or set()
        rows = [row for row in rows if row[1] is not None and row[1].id in matched_user_ids]

    return rows


def _send_campaign_now(
    db: OrmSession,
    campaign: PushCampaign,
    *,
    explicit_audience: Optional[List[Dict[str, Any]]] = None,
    segment: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    rows = _eligible_device_rows(db, campaign.audience, explicit_audience=explicit_audience, segment=segment)
    tokens = []
    target_devices: List[PushDevice] = []
    seen = set()
    for device, _ in rows:
        token = (device.push_token or '').strip()
        if not token or token in seen:
            continue
        seen.add(token)
        tokens.append(token)
        target_devices.append(device)

    if not tokens:
        campaign.status = 'no_targets'
        campaign.error_message = 'No eligible push tokens registered'
        campaign.updated_at = datetime.utcnow()
        db.add(campaign)
        db.commit()
        return {'sentCount': 0, 'failureCount': 0, 'status': 'no_targets'}

    data: Dict[str, str] = {}
    if campaign.target_tab:
        data['targetTab'] = campaign.target_tab
    if campaign.target_url:
        data['targetUrl'] = campaign.target_url
    data['kind'] = campaign.kind

    app = _firebase_app()
    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=campaign.title,
            body=campaign.message,
        ),
        data=data,
        tokens=tokens,
    )
    response = messaging.send_each_for_multicast(message, app=app)

    invalidated_count = 0
    for device, result in zip(target_devices, response.responses):
        if result.success:
            continue
        if _should_invalidate_push_target(result.exception):
            device.status = 'invalid'
            device.updated_at = datetime.utcnow()
            db.add(device)
            invalidated_count += 1

    campaign.sent_at = datetime.utcnow()
    campaign.updated_at = datetime.utcnow()
    campaign.status = 'sent' if response.failure_count == 0 else 'partial_failure'
    campaign.error_message = None if response.failure_count == 0 else f'{response.failure_count} failed'
    db.add(campaign)
    db.commit()

    return {
        'sentCount': response.success_count,
        'failureCount': response.failure_count,
        'invalidatedCount': invalidated_count,
        'status': campaign.status,
    }


def _should_invalidate_push_target(error: Optional[Exception]) -> bool:
    if error is None:
        return False
    error_name = type(error).__name__
    message = str(error).lower()
    return error_name in {
        'SenderIdMismatchError',
        'UnregisteredError',
    } or 'senderid mismatch' in message or 'not registered' in message or 'invalid registration token' in message


def _parse_debug_info(value: Optional[str]) -> Optional[Dict[str, Any]]:
    if not value:
        return None
    try:
        parsed = json.loads(value)
    except Exception:
        return {'raw': value}
    return parsed if isinstance(parsed, dict) else {'raw': value}


def serialize_push_device(row: PushDevice) -> Dict[str, Any]:
    return {
        'id': row.id,
        'userId': row.user_id,
        'installId': row.install_id,
        'platform': row.platform,
        'pushProvider': row.push_provider,
        'hasPushToken': bool((row.push_token or '').strip()),
        'notificationsEnabled': row.notifications_enabled,
        'status': row.status,
        'appVersion': row.app_version,
        'locale': row.locale,
        'debugInfo': _parse_debug_info(row.push_debug_json),
        'lastRegisteredAt': row.last_registered_at.isoformat() if row.last_registered_at else None,
        'lastSeenAt': row.last_seen_at.isoformat() if row.last_seen_at else None,
        'updatedAt': row.updated_at.isoformat() if row.updated_at else None,
    }


def serialize_push_campaign(row: PushCampaign) -> Dict[str, Any]:
    segment = None
    if (row.segment_json or '').strip():
        try:
            segment = json.loads(row.segment_json)
        except Exception:
            segment = {'raw': row.segment_json}
    return {
        'id': row.id,
        'kind': row.kind,
        'audience': row.audience,
        'status': row.status,
        'title': row.title,
        'message': row.message,
        'targetTab': row.target_tab,
        'targetUrl': row.target_url,
        'requestedBy': row.requested_by,
        'requestedBySource': row.requested_by_source,
        'segment': segment,
        'deliveryProvider': row.delivery_provider,
        'errorMessage': row.error_message,
        'createdAt': row.created_at.isoformat() if row.created_at else None,
        'sentAt': row.sent_at.isoformat() if row.sent_at else None,
    }
