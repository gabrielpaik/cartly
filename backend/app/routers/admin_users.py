from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session as OrmSession

from ..deps import db_dep
from ..services.admin_user_service import (
    archive_legacy_guest,
    get_user_detail_with_carts,
    list_legacy_guests,
    list_users_for_admin,
    merge_legacy_guest_into_user,
)
from .admin_common import ADMIN_ROUTE_DEP

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/users')
def list_users(
    accountType: str = Query(default='all', pattern='^(all|member|guest)$'),
    query: str = Query(default=''),
    lastSeenWithinDays: Optional[int] = Query(default=None, ge=1, le=3650),
    sessionCountMin: Optional[int] = Query(default=None, ge=0, le=100000),
    scanCountMin: Optional[int] = Query(default=None, ge=0, le=100000),
    scanCountLt: Optional[int] = Query(default=None, ge=0, le=100000),
    savedCartCountMin: Optional[int] = Query(default=None, ge=0, le=100000),
    readyPushOnly: bool = Query(default=False),
    regionSegmentMode: str = Query(default='none', pattern='^(none|recent|frequent|primary)$'),
    regionKeys: str = Query(default=''),
    regionRecentWithinDays: Optional[int] = Query(default=None, ge=1, le=3650),
    regionVisitCountMin: Optional[int] = Query(default=None, ge=1, le=100000),
    limit: int = Query(default=500, ge=1, le=5000),
    db: OrmSession = Depends(db_dep),
):
    return {
        'ok': True,
        'data': list_users_for_admin(
            db,
            account_type=accountType,
            query=query,
            last_seen_within_days=lastSeenWithinDays,
            session_count_min=sessionCountMin,
            scan_count_min=scanCountMin,
            scan_count_lt=scanCountLt,
            saved_cart_count_min=savedCartCountMin,
            ready_push_only=readyPushOnly,
            region_segment_mode=regionSegmentMode,
            region_keys=[item.strip() for item in regionKeys.split(',') if item.strip()],
            region_recent_within_days=regionRecentWithinDays,
            region_visit_count_min=regionVisitCountMin,
            limit=limit,
        ),
    }


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
