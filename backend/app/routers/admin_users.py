from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session as OrmSession

from ..deps import db_dep
from ..services.admin_user_service import (
    archive_legacy_guest,
    get_user_detail_with_carts,
    list_legacy_guests,
    merge_legacy_guest_into_user,
)
from .admin_common import ADMIN_ROUTE_DEP

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/users')
def list_users(db: OrmSession = Depends(db_dep)):
    rows = db.execute(
        text(
            "select id, display_name, email, auth_provider, is_guest, created_at, last_seen_at, guest_key, last_device_platform, last_app_version "
            "from users where status = 'active' order by created_at desc limit 100"
        )
    )
    users = [
        {
            'id': r[0],
            'displayName': r[1],
            'email': r[2],
            'provider': r[3],
            'isGuest': r[4],
            'createdAt': r[5].isoformat() if r[5] else None,
            'lastSeenAt': r[6].isoformat() if r[6] else None,
            'guestKey': r[7],
            'lastDevicePlatform': r[8],
            'lastAppVersion': r[9],
        }
        for r in rows
    ]
    return {'ok': True, 'data': {'users': users}}


@router.get('/users/legacy-guests')
def admin_legacy_guests(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': list_legacy_guests(db)}


@router.post('/users/{user_id}/archive-legacy')
def admin_archive_legacy_guest(user_id: str, db: OrmSession = Depends(db_dep)):
    result = archive_legacy_guest(db, user_id)
    if not result.get('ok'):
        return {'ok': False, 'error': {'code': result['code'], 'message': result['message']}}
    return {'ok': True, 'data': result}


@router.post('/users/{user_id}/merge-legacy')
def admin_merge_legacy_guest(user_id: str, payload: dict, db: OrmSession = Depends(db_dep)):
    target_user_id = str(payload.get('targetUserId') or '').strip()
    result = merge_legacy_guest_into_user(db, user_id, target_user_id)
    if not result.get('ok'):
        return {'ok': False, 'error': {'code': result['code'], 'message': result['message']}}
    return {'ok': True, 'data': result}


@router.get('/users/{user_id}/carts')
def admin_user_carts(user_id: str, limit: int = Query(default=200, ge=1, le=500), db: OrmSession = Depends(db_dep)):
    detail = get_user_detail_with_carts(db, user_id, limit=limit)
    if detail is None:
        return {
            'ok': False,
            'error': {
                'code': 'USER_NOT_FOUND',
                'message': 'user를 찾지 못했어',
            },
        }
    return {'ok': True, 'data': detail}
