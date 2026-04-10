from datetime import datetime
from typing import Optional

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session as OrmSession, selectinload

from ..db.models import AdImpression, AppEvent, Cart, ScanFailureLog, ScanFeedback, ScanJob, Session, User
from .cart_service import serialize_cart


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
