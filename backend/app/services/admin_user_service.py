from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import and_, case, func, or_, select, update
from sqlalchemy.orm import Session as OrmSession, selectinload

from ..db.models import AdImpression, AppEvent, Cart, PushDevice, ScanFailureLog, ScanFeedback, ScanJob, Session, User
from .cart_service import serialize_cart


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

    rows = list(
        db.execute(
            stmt.order_by(func.coalesce(User.last_seen_at, User.created_at).desc(), User.created_at.desc()).limit(max(1, min(limit, 5000)))
        ).all()
    )

    users = [
        {
            'id': row[0],
            'displayName': row[1],
            'email': row[2],
            'provider': row[3],
            'isGuest': row[4],
            'guestCode': row[5],
            'createdAt': row[6].isoformat() if row[6] else None,
            'lastSeenAt': row[7].isoformat() if row[7] else None,
            'guestKey': row[8],
            'lastDevicePlatform': row[9],
            'lastAppVersion': row[10],
            'cartCount': int(row[11] or 0),
            'savedCartCount': int(row[11] or 0),
            'sessionCount': int(row[12] or 0),
            'scanCount': int(row[13] or 0),
            'pushDeviceCount': int(row[14] or 0),
            'readyPushDeviceCount': int(row[15] or 0),
            'lastSavedAt': row[16].isoformat() if row[16] else None,
            'lastScanAt': row[17].isoformat() if row[17] else None,
        }
        for row in rows
    ]

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

    total_carts = len(carts)
    total_items = sum(cart.total_count_cached for cart in carts)
    total_value = sum(cart.total_price_cached for cart in carts)
    last_saved_at = carts[0].created_at.isoformat() if carts else None
    first_saved_at = carts[-1].created_at.isoformat() if carts else None

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
            'mergedAt': user.merged_at.isoformat() if user.merged_at else None,
            'lastDevicePlatform': user.last_device_platform,
            'lastAppVersion': user.last_app_version,
            'createdAt': user.created_at.isoformat() if user.created_at else None,
            'lastSeenAt': user.last_seen_at.isoformat() if user.last_seen_at else None,
        },
        'summary': {
            'totalCarts': total_carts,
            'totalItems': total_items,
            'totalValue': total_value,
            'firstSavedAt': first_saved_at,
            'lastSavedAt': last_saved_at,
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
                'createdAt': row[2].isoformat() if row[2] else None,
                'lastSeenAt': row[3].isoformat() if row[3] else None,
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
