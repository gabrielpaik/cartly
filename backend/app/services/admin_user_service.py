from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import and_, case, func, or_, select, update
from sqlalchemy.orm import Session as OrmSession, selectinload

from ..db.models import AdImpression, AppEvent, Cart, PushDevice, ScanFailureLog, ScanFeedback, ScanJob, Session, User
from .cart_service import serialize_cart
from .user_region_service import (
    build_user_region_summary_map,
    list_user_region_events,
    list_user_region_profiles,
    resolve_user_ids_for_region_segment,
)


def _iso(value: Optional[datetime]) -> Optional[str]:
    return value.isoformat() if value else None


def _days_since(value: Optional[datetime]) -> Optional[int]:
    if value is None:
        return None
    delta = datetime.utcnow() - value
    return max(0, int(delta.total_seconds() // 86400))


def _last_activity(last_seen_at: Optional[datetime], last_saved_at: Optional[datetime], last_scan_at: Optional[datetime]) -> tuple:
    candidates = [
        ('seen', last_seen_at),
        ('saved', last_saved_at),
        ('scan', last_scan_at),
    ]
    best = None
    for activity_type, activity_at in candidates:
        if activity_at is None:
            continue
        if best is None or activity_at > best[1]:
            best = (activity_type, activity_at)
    return best if best is not None else (None, None)


def _customer_state(
    *,
    is_guest: bool,
    status: str,
    guest_key: Optional[str],
    email: Optional[str],
    created_at: Optional[datetime],
    last_seen_at: Optional[datetime],
    last_saved_at: Optional[datetime],
    last_scan_at: Optional[datetime],
    session_count: int,
    scan_count: int,
    saved_cart_count: int,
    push_device_count: int,
    ready_push_device_count: int,
    merged_into_user_id: Optional[str] = None,
) -> dict:
    days_since_seen = _days_since(last_seen_at)
    days_since_created = _days_since(created_at)
    last_activity_type, last_activity_at = _last_activity(last_seen_at, last_saved_at, last_scan_at)

    if status == 'merged' or merged_into_user_id:
        lifecycle_stage = 'merged'
        lifecycle_label = 'merged customer'
    elif is_guest and guest_key is None and saved_cart_count > 0:
        lifecycle_stage = 'legacy_guest_with_carts'
        lifecycle_label = 'legacy guest with carts'
    elif is_guest and guest_key is None:
        lifecycle_stage = 'legacy_guest'
        lifecycle_label = 'legacy guest'
    elif is_guest:
        if days_since_created is not None and days_since_created <= 7 and session_count <= 2 and saved_cart_count == 0:
            lifecycle_stage = 'guest_new'
            lifecycle_label = 'new guest'
        elif days_since_seen is not None and days_since_seen > 30:
            lifecycle_stage = 'guest_dormant'
            lifecycle_label = 'dormant guest'
        else:
            lifecycle_stage = 'guest_active'
            lifecycle_label = 'active guest'
    else:
        if days_since_created is not None and days_since_created <= 7 and session_count <= 3 and saved_cart_count == 0:
            lifecycle_stage = 'member_new'
            lifecycle_label = 'new member'
        elif days_since_seen is not None and days_since_seen > 30:
            lifecycle_stage = 'member_dormant'
            lifecycle_label = 'dormant member'
        elif saved_cart_count >= 3 or scan_count >= 10 or session_count >= 10:
            lifecycle_stage = 'member_core'
            lifecycle_label = 'core member'
        else:
            lifecycle_stage = 'member_active'
            lifecycle_label = 'active member'

    if ready_push_device_count > 0:
        reachability_state = 'push_ready'
        reachability_label = 'push ready'
    elif push_device_count > 0:
        reachability_state = 'push_blocked'
        reachability_label = 'device exists, push blocked'
    elif email:
        reachability_state = 'account_only'
        reachability_label = 'account only'
    else:
        reachability_state = 'unreachable'
        reachability_label = 'no direct reachability'

    if is_guest and guest_key is None and saved_cart_count > 0:
        operator_action = 'merge_review'
        operator_action_label = 'merge review'
    elif ready_push_device_count > 0 and days_since_seen is not None and days_since_seen > 14 and saved_cart_count > 0:
        operator_action = 'winback_push'
        operator_action_label = 'win-back push candidate'
    elif ready_push_device_count == 0 and push_device_count > 0:
        operator_action = 'recover_push_optin'
        operator_action_label = 'recover push opt-in'
    elif not is_guest and saved_cart_count == 0 and scan_count > 0:
        operator_action = 'nudge_first_save'
        operator_action_label = 'nudge first saved cart'
    elif days_since_seen is not None and days_since_seen > 30:
        operator_action = 'dormant_review'
        operator_action_label = 'dormant review'
    elif days_since_created is not None and days_since_created <= 7:
        operator_action = 'onboarding_watch'
        operator_action_label = 'onboarding watch'
    else:
        operator_action = 'monitor'
        operator_action_label = 'monitor'

    return {
        'lifecycleStage': lifecycle_stage,
        'lifecycleLabel': lifecycle_label,
        'reachabilityState': reachability_state,
        'reachabilityLabel': reachability_label,
        'operatorAction': operator_action,
        'operatorActionLabel': operator_action_label,
        'daysSinceSeen': days_since_seen,
        'daysSinceCreated': days_since_created,
        'lastActivityType': last_activity_type,
        'lastActivityAt': _iso(last_activity_at),
    }


def _serialize_push_device(device: PushDevice) -> dict:
    ready = bool(
        device.status == 'active'
        and device.notifications_enabled
        and (device.push_token or '').strip()
    )
    return {
        'id': device.id,
        'installId': device.install_id,
        'platform': device.platform,
        'provider': device.push_provider,
        'status': device.status,
        'notificationsEnabled': bool(device.notifications_enabled),
        'hasPushToken': bool((device.push_token or '').strip()),
        'isReady': ready,
        'appVersion': device.app_version,
        'locale': device.locale,
        'lastRegisteredAt': _iso(device.last_registered_at),
        'lastSeenAt': _iso(device.last_seen_at),
        'createdAt': _iso(device.created_at),
    }


def list_users_for_admin(
    db: OrmSession,
    *,
    account_type: str = 'all',
    query: str = '',
    last_seen_within_days: Optional[int] = None,
    session_count_min: Optional[int] = None,
    scan_count_min: Optional[int] = None,
    scan_count_lt: Optional[int] = None,
    saved_cart_count_min: Optional[int] = None,
    ready_push_only: bool = False,
    region_segment_mode: str = 'none',
    region_keys: Optional[list[str]] = None,
    region_recent_within_days: Optional[int] = None,
    region_visit_count_min: Optional[int] = None,
    limit: int = 500,
) -> dict:
    cart_count = (
        select(
            Cart.user_id.label('user_id'),
            func.count(Cart.id).label('saved_cart_count'),
            func.max(Cart.created_at).label('last_saved_at'),
        )
        .where(Cart.deleted_at.is_(None))
        .group_by(Cart.user_id)
        .subquery()
    )
    session_count = (
        select(
            Session.user_id.label('user_id'),
            func.count(Session.id).label('session_count'),
            func.max(Session.last_seen_at).label('last_session_at'),
        )
        .where(Session.user_id.is_not(None))
        .group_by(Session.user_id)
        .subquery()
    )
    scan_count = (
        select(
            ScanJob.user_id.label('user_id'),
            func.count(ScanJob.id).label('scan_count'),
            func.max(ScanJob.created_at).label('last_scan_at'),
        )
        .where(ScanJob.user_id.is_not(None))
        .group_by(ScanJob.user_id)
        .subquery()
    )
    push_count = (
        select(
            PushDevice.user_id.label('user_id'),
            func.count(PushDevice.id).label('push_device_count'),
            func.sum(
                case(
                    (
                        and_(
                            PushDevice.status == 'active',
                            PushDevice.notifications_enabled.is_(True),
                            PushDevice.push_token.is_not(None),
                        ),
                        1,
                    ),
                    else_=0,
                )
            ).label('ready_push_device_count'),
        )
        .where(PushDevice.user_id.is_not(None))
        .group_by(PushDevice.user_id)
        .subquery()
    )

    stmt = (
        select(
            User.id,
            User.display_name,
            User.email,
            User.auth_provider,
            User.is_guest,
            User.guest_code,
            User.created_at,
            User.last_seen_at,
            User.guest_key,
            User.last_device_platform,
            User.last_app_version,
            User.status,
            User.merged_into_user_id,
            User.last_region_city,
            User.last_region_district,
            User.last_region_neighborhood,
            User.last_region_label,
            User.last_region_captured_at,
            func.coalesce(cart_count.c.saved_cart_count, 0).label('saved_cart_count'),
            func.coalesce(session_count.c.session_count, 0).label('session_count'),
            func.coalesce(scan_count.c.scan_count, 0).label('scan_count'),
            func.coalesce(push_count.c.push_device_count, 0).label('push_device_count'),
            func.coalesce(push_count.c.ready_push_device_count, 0).label('ready_push_device_count'),
            cart_count.c.last_saved_at,
            scan_count.c.last_scan_at,
        )
        .outerjoin(cart_count, cart_count.c.user_id == User.id)
        .outerjoin(session_count, session_count.c.user_id == User.id)
        .outerjoin(scan_count, scan_count.c.user_id == User.id)
        .outerjoin(push_count, push_count.c.user_id == User.id)
        .where(User.status == 'active')
    )

    if account_type == 'member':
        stmt = stmt.where(User.is_guest.is_(False))
    elif account_type == 'guest':
        stmt = stmt.where(User.is_guest.is_(True))

    trimmed = query.strip().lower()
    if trimmed:
        like = f'%{trimmed}%'
        stmt = stmt.where(
            or_(
                func.lower(func.coalesce(User.id, '')).like(like),
                func.lower(func.coalesce(User.display_name, '')).like(like),
                func.lower(func.coalesce(User.email, '')).like(like),
                func.lower(func.coalesce(User.auth_provider, '')).like(like),
                func.lower(func.coalesce(User.guest_code, '')).like(like),
                func.lower(func.coalesce(User.last_device_platform, '')).like(like),
            )
        )

    if last_seen_within_days is not None:
        since = datetime.utcnow() - timedelta(days=max(1, last_seen_within_days))
        stmt = stmt.where(User.last_seen_at.is_not(None), User.last_seen_at >= since)
    if session_count_min is not None:
        stmt = stmt.where(func.coalesce(session_count.c.session_count, 0) >= max(0, session_count_min))
    if scan_count_min is not None:
        stmt = stmt.where(func.coalesce(scan_count.c.scan_count, 0) >= max(0, scan_count_min))
    if scan_count_lt is not None:
        stmt = stmt.where(func.coalesce(scan_count.c.scan_count, 0) < max(0, scan_count_lt))
    if saved_cart_count_min is not None:
        stmt = stmt.where(func.coalesce(cart_count.c.saved_cart_count, 0) >= max(0, saved_cart_count_min))
    if ready_push_only:
        stmt = stmt.where(func.coalesce(push_count.c.ready_push_device_count, 0) > 0)

    matched_region_user_ids = resolve_user_ids_for_region_segment(
        db,
        mode=region_segment_mode,
        region_keys=region_keys,
        recent_within_days=region_recent_within_days,
        min_visits=region_visit_count_min,
    )
    if matched_region_user_ids is not None:
        if not matched_region_user_ids:
            return {
                'summary': {
                    'filteredUsers': 0,
                    'members': 0,
                    'guests': 0,
                    'readyPushUsers': 0,
                    'totalSessions': 0,
                    'totalScans': 0,
                    'totalSavedCarts': 0,
                },
                'users': [],
            }
        stmt = stmt.where(User.id.in_(sorted(matched_region_user_ids)))

    rows = list(
        db.execute(
            stmt.order_by(func.coalesce(User.last_seen_at, User.created_at).desc(), User.created_at.desc()).limit(max(1, min(limit, 5000)))
        ).all()
    )

    region_summary_map = build_user_region_summary_map(db, [row[0] for row in rows])

    users = []
    for row in rows:
        region_summary = region_summary_map.get(row[0], {})
        user = {
            'id': row[0],
            'displayName': row[1],
            'email': row[2],
            'provider': row[3],
            'isGuest': row[4],
            'guestCode': row[5],
            'createdAt': _iso(row[6]),
            'lastSeenAt': _iso(row[7]),
            'guestKey': row[8],
            'lastDevicePlatform': row[9],
            'lastAppVersion': row[10],
            'status': row[11],
            'mergedIntoUserId': row[12],
            'lastRegionCity': row[13],
            'lastRegionDistrict': row[14],
            'lastRegionNeighborhood': row[15],
            'lastRegionLabel': row[16],
            'lastRegionCapturedAt': _iso(row[17]),
            'regionActivityCount': int(region_summary.get('regionActivityCount') or 0),
            'recentRegionCount30d': int(region_summary.get('recentRegionCount30d') or 0),
            'primaryRegionKey': region_summary.get('primaryRegionKey'),
            'primaryRegionLabel': region_summary.get('primaryRegionLabel'),
            'topRegionLabels': region_summary.get('topRegionLabels') or [],
            'topRegionSummary': region_summary.get('topRegionSummary'),
            'cartCount': int(row[18] or 0),
            'savedCartCount': int(row[18] or 0),
            'sessionCount': int(row[19] or 0),
            'scanCount': int(row[20] or 0),
            'pushDeviceCount': int(row[21] or 0),
            'readyPushDeviceCount': int(row[22] or 0),
            'lastSavedAt': _iso(row[23]),
            'lastScanAt': _iso(row[24]),
        }
        user.update(
            _customer_state(
                is_guest=bool(user['isGuest']),
                status=str(user.get('status') or 'active'),
                guest_key=user.get('guestKey'),
                email=user.get('email'),
                created_at=row[6],
                last_seen_at=row[7],
                last_saved_at=row[23],
                last_scan_at=row[24],
                session_count=int(user['sessionCount']),
                scan_count=int(user['scanCount']),
                saved_cart_count=int(user['savedCartCount']),
                push_device_count=int(user['pushDeviceCount']),
                ready_push_device_count=int(user['readyPushDeviceCount']),
                merged_into_user_id=user.get('mergedIntoUserId'),
            )
        )
        users.append(user)

    return {
        'summary': {
            'filteredUsers': len(users),
            'members': sum(1 for user in users if not user['isGuest']),
            'guests': sum(1 for user in users if user['isGuest']),
            'readyPushUsers': sum(1 for user in users if user['readyPushDeviceCount'] > 0),
            'totalSessions': sum(user['sessionCount'] for user in users),
            'totalScans': sum(user['scanCount'] for user in users),
            'totalSavedCarts': sum(user['savedCartCount'] for user in users),
        },
        'users': users,
    }



def get_user_detail_with_carts(db: OrmSession, user_id: str, limit: int = 200) -> Optional[dict]:
    user = db.get(User, user_id)
    if user is None:
        return None

    carts = list(
        db.scalars(
            select(Cart)
            .options(selectinload(Cart.items))
            .where(Cart.user_id == user_id, Cart.deleted_at.is_(None))
            .order_by(Cart.created_at.desc())
            .limit(limit)
        ).all()
    )
    session_rows = list(
        db.scalars(
            select(Session)
            .where(Session.user_id == user_id)
            .order_by(Session.last_seen_at.desc(), Session.created_at.desc())
            .limit(12)
        ).all()
    )
    scan_rows = list(
        db.scalars(
            select(ScanJob)
            .where(ScanJob.user_id == user_id)
            .order_by(ScanJob.created_at.desc())
            .limit(12)
        ).all()
    )
    push_rows = list(
        db.scalars(
            select(PushDevice)
            .where(PushDevice.user_id == user_id)
            .order_by(PushDevice.last_seen_at.desc(), PushDevice.updated_at.desc())
            .limit(8)
        ).all()
    )
    app_event_rows = list(
        db.scalars(
            select(AppEvent)
            .where(AppEvent.user_id == user_id)
            .order_by(func.coalesce(AppEvent.client_timestamp, AppEvent.created_at).desc())
            .limit(12)
        ).all()
    )
    region_profiles = list_user_region_profiles(db, user_id, limit=12)
    region_events = list_user_region_events(db, user_id, limit=20)

    total_carts = len(carts)
    total_items = sum((cart.total_count_cached or 0) for cart in carts)
    total_value = sum((cart.total_price_cached or 0) for cart in carts)
    last_saved_at = carts[0].created_at if carts else None
    first_saved_at = carts[-1].created_at if carts else None
    total_sessions = db.scalar(select(func.count(Session.id)).where(Session.user_id == user_id)) or 0
    total_scans = db.scalar(select(func.count(ScanJob.id)).where(ScanJob.user_id == user_id)) or 0
    total_push_devices = db.scalar(select(func.count(PushDevice.id)).where(PushDevice.user_id == user_id)) or 0
    ready_push_devices = db.scalar(
        select(func.count(PushDevice.id)).where(
            PushDevice.user_id == user_id,
            PushDevice.status == 'active',
            PushDevice.notifications_enabled.is_(True),
            PushDevice.push_token.is_not(None),
        )
    ) or 0
    accepted_feedback_count = db.scalar(
        select(func.count(ScanFeedback.id)).where(ScanFeedback.user_id == user_id, ScanFeedback.accepted.is_(True))
    ) or 0
    feedback_count = db.scalar(select(func.count(ScanFeedback.id)).where(ScanFeedback.user_id == user_id)) or 0
    failure_count = db.scalar(select(func.count(ScanFailureLog.id)).where(ScanFailureLog.user_id == user_id)) or 0

    status_rows = list(
        db.execute(
            select(ScanJob.status, func.count(ScanJob.id))
            .where(ScanJob.user_id == user_id)
            .group_by(ScanJob.status)
            .order_by(func.count(ScanJob.id).desc(), ScanJob.status.asc())
        ).all()
    )
    event_rows = list(
        db.execute(
            select(AppEvent.event_name, AppEvent.screen_name, func.count(AppEvent.id))
            .where(AppEvent.user_id == user_id)
            .group_by(AppEvent.event_name, AppEvent.screen_name)
            .order_by(func.count(AppEvent.id).desc(), AppEvent.event_name.asc())
            .limit(8)
        ).all()
    )
    latest_failure = db.execute(
        select(ScanFailureLog)
        .where(ScanFailureLog.user_id == user_id)
        .order_by(ScanFailureLog.created_at.desc())
        .limit(1)
    ).scalar_one_or_none()

    lifecycle = _customer_state(
        is_guest=bool(user.is_guest),
        status=user.status or 'active',
        guest_key=user.guest_key,
        email=user.email,
        created_at=user.created_at,
        last_seen_at=user.last_seen_at,
        last_saved_at=last_saved_at,
        last_scan_at=scan_rows[0].created_at if scan_rows else None,
        session_count=int(total_sessions),
        scan_count=int(total_scans),
        saved_cart_count=int(total_carts),
        push_device_count=int(total_push_devices),
        ready_push_device_count=int(ready_push_devices),
        merged_into_user_id=user.merged_into_user_id,
    )

    timeline = []
    for session in session_rows[:6]:
        timeline.append({
            'kind': 'session',
            'at': _iso(session.last_seen_at or session.created_at),
            'title': 'Session active',
            'note': f"expires {_iso(session.expires_at) or '-'} · {'guest' if session.is_guest else 'member'}",
        })
    for scan in scan_rows[:6]:
        timeline.append({
            'kind': 'scan',
            'at': _iso(scan.finished_at or scan.created_at),
            'title': f"Scan {scan.status}",
            'note': scan.error_code or scan.error_message or 'scan job',
        })
    for cart in carts[:6]:
        timeline.append({
            'kind': 'cart',
            'at': _iso(cart.created_at),
            'title': f"Saved cart {cart.title or cart.id}",
            'note': f"{int(cart.total_count_cached or 0)} items · ₩{int(cart.total_price_cached or 0):,}",
        })
    for event in app_event_rows[:6]:
        timeline.append({
            'kind': 'event',
            'at': _iso(event.client_timestamp or event.created_at),
            'title': event.event_name,
            'note': event.screen_name or event.device_platform or 'app event',
        })
    timeline.sort(key=lambda item: item.get('at') or '', reverse=True)

    return {
        'user': {
            'id': user.id,
            'displayName': user.display_name,
            'guestCode': user.guest_code,
            'email': user.email,
            'provider': user.auth_provider,
            'status': user.status,
            'isGuest': user.is_guest,
            'guestKey': user.guest_key,
            'mergedIntoUserId': user.merged_into_user_id,
            'mergedAt': _iso(user.merged_at),
            'lastDevicePlatform': user.last_device_platform,
            'lastAppVersion': user.last_app_version,
            'lastRegionCity': user.last_region_city,
            'lastRegionDistrict': user.last_region_district,
            'lastRegionNeighborhood': user.last_region_neighborhood,
            'lastRegionLabel': user.last_region_label,
            'lastRegionCapturedAt': _iso(user.last_region_captured_at),
            'createdAt': _iso(user.created_at),
            'lastSeenAt': _iso(user.last_seen_at),
        },
        'summary': {
            'totalCarts': total_carts,
            'totalItems': total_items,
            'totalValue': total_value,
            'firstSavedAt': _iso(first_saved_at),
            'lastSavedAt': _iso(last_saved_at),
            'totalSessions': int(total_sessions),
            'totalScans': int(total_scans),
            'pushDeviceCount': int(total_push_devices),
            'readyPushDeviceCount': int(ready_push_devices),
        },
        'lifecycle': lifecycle,
        'push': {
            'reachabilityState': lifecycle['reachabilityState'],
            'reachabilityLabel': lifecycle['reachabilityLabel'],
            'deviceCount': int(total_push_devices),
            'readyDeviceCount': int(ready_push_devices),
            'devices': [_serialize_push_device(device) for device in push_rows],
        },
        'scan': {
            'totalScans': int(total_scans),
            'feedbackCount': int(feedback_count),
            'acceptedFeedbackCount': int(accepted_feedback_count),
            'failureCount': int(failure_count),
            'lastScanAt': _iso(scan_rows[0].created_at) if scan_rows else None,
            'latestFailure': {
                'at': _iso(latest_failure.created_at) if latest_failure else None,
                'stage': latest_failure.stage if latest_failure else None,
                'errorCode': latest_failure.error_code if latest_failure else None,
                'errorMessage': latest_failure.error_message if latest_failure else None,
            },
            'statusSummary': [
                {'status': row[0], 'count': int(row[1] or 0)}
                for row in status_rows
            ],
            'recent': [
                {
                    'id': scan.id,
                    'status': scan.status,
                    'createdAt': _iso(scan.created_at),
                    'finishedAt': _iso(scan.finished_at),
                    'errorCode': scan.error_code,
                    'errorMessage': scan.error_message,
                }
                for scan in scan_rows[:6]
            ],
        },
        'activity': {
            'lastActivityType': lifecycle['lastActivityType'],
            'lastActivityAt': lifecycle['lastActivityAt'],
            'timeline': timeline[:12],
            'eventSummary': [
                {
                    'eventName': row[0],
                    'screenName': row[1],
                    'count': int(row[2] or 0),
                }
                for row in event_rows
            ],
        },
        'regions': {
            'currentLabel': user.last_region_label,
            'currentCapturedAt': _iso(user.last_region_captured_at),
            'profileCount': len(region_profiles),
            'profiles': region_profiles,
            'recentEvents': region_events,
        },
        'carts': [serialize_cart(cart) for cart in carts],
    }


def _legacy_guest_rows(db: OrmSession):
    cart_count = (
        select(Cart.user_id, func.count(Cart.id).label('cart_count'))
        .where(Cart.deleted_at.is_(None))
        .group_by(Cart.user_id)
        .subquery()
    )
    session_count = (
        select(Session.user_id, func.count(Session.id).label('session_count'))
        .group_by(Session.user_id)
        .subquery()
    )

    stmt = (
        select(
            User.id,
            User.display_name,
            User.created_at,
            User.last_seen_at,
            User.last_device_platform,
            User.last_app_version,
            func.coalesce(cart_count.c.cart_count, 0),
            func.coalesce(session_count.c.session_count, 0),
        )
        .outerjoin(cart_count, cart_count.c.user_id == User.id)
        .outerjoin(session_count, session_count.c.user_id == User.id)
        .where(
            User.status == 'active',
            User.is_guest.is_(True),
            User.guest_key.is_(None),
        )
        .order_by(User.created_at.desc())
    )
    return list(db.execute(stmt).all())


def list_legacy_guests(db: OrmSession) -> dict:
    rows = _legacy_guest_rows(db)
    return {
        'summary': {
            'count': len(rows),
            'withCarts': sum(1 for row in rows if row[6] > 0),
            'withoutCarts': sum(1 for row in rows if row[6] == 0),
        },
        'users': [
            {
                'id': row[0],
                'displayName': row[1],
                'createdAt': _iso(row[2]),
                'lastSeenAt': _iso(row[3]),
                'lastDevicePlatform': row[4],
                'lastAppVersion': row[5],
                'cartCount': int(row[6] or 0),
                'sessionCount': int(row[7] or 0),
            }
            for row in rows
        ],
    }


def archive_legacy_guest(db: OrmSession, user_id: str) -> dict:
    user = db.get(User, user_id)
    if user is None or user.status != 'active' or not user.is_guest or user.guest_key is not None:
        return {'ok': False, 'code': 'LEGACY_GUEST_NOT_FOUND', 'message': 'archive 가능한 legacy guest가 아니야'}

    active_cart_count = db.scalar(
        select(func.count(Cart.id)).where(Cart.user_id == user_id, Cart.deleted_at.is_(None))
    ) or 0
    if active_cart_count > 0:
        return {'ok': False, 'code': 'LEGACY_GUEST_HAS_CARTS', 'message': '카트가 있는 legacy guest는 archive 전에 merge 판단이 필요해'}

    user.status = 'archived'
    user.updated_at = datetime.utcnow()
    db.add(user)
    db.commit()
    return {'ok': True, 'userId': user_id, 'archived': True}


def merge_legacy_guest_into_user(db: OrmSession, legacy_user_id: str, target_user_id: str) -> dict:
    legacy = db.get(User, legacy_user_id)
    target = db.get(User, target_user_id)

    if legacy is None or legacy.status != 'active' or not legacy.is_guest or legacy.guest_key is not None:
        return {'ok': False, 'code': 'LEGACY_GUEST_NOT_FOUND', 'message': 'merge 가능한 legacy guest가 아니야'}
    if target is None or target.status != 'active':
        return {'ok': False, 'code': 'TARGET_USER_NOT_FOUND', 'message': '대상 user를 찾지 못했어'}
    if legacy.id == target.id:
        return {'ok': False, 'code': 'INVALID_MERGE_TARGET', 'message': '같은 user로 merge할 수는 없어'}

    db.execute(update(Cart).where(Cart.user_id == legacy.id).values(user_id=target.id))
    db.execute(update(ScanJob).where(ScanJob.user_id == legacy.id).values(user_id=target.id))
    db.execute(update(ScanFeedback).where(ScanFeedback.user_id == legacy.id).values(user_id=target.id))
    db.execute(update(ScanFailureLog).where(ScanFailureLog.user_id == legacy.id).values(user_id=target.id))
    db.execute(update(AppEvent).where(AppEvent.user_id == legacy.id).values(user_id=target.id))
    db.execute(update(AdImpression).where(AdImpression.user_id == legacy.id).values(user_id=target.id))
    db.execute(update(Session).where(Session.user_id == legacy.id).values(user_id=target.id, is_guest=False))

    if legacy.last_seen_at and (target.last_seen_at is None or legacy.last_seen_at > target.last_seen_at):
        target.last_seen_at = legacy.last_seen_at
    if not target.last_device_platform and legacy.last_device_platform:
        target.last_device_platform = legacy.last_device_platform
    if not target.last_app_version and legacy.last_app_version:
        target.last_app_version = legacy.last_app_version

    legacy.status = 'merged'
    legacy.merged_into_user_id = target.id
    legacy.merged_at = datetime.utcnow()
    legacy.updated_at = datetime.utcnow()
    db.add(target)
    db.add(legacy)
    db.commit()

    return {'ok': True, 'legacyUserId': legacy_user_id, 'targetUserId': target_user_id, 'merged': True}
