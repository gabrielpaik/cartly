from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..deps import db_dep
from ..schemas.branding import BrandingRequest
from ..services.admin_service import dashboard_summary
from ..services.branding_service import get_branding, save_branding

router = APIRouter()


@router.get('/dashboard/summary')
def get_dashboard_summary(db: OrmSession = Depends(db_dep)):
    return {
        'ok': True,
        'data': dashboard_summary(db),
    }


@router.get('/users')
def list_users(db: OrmSession = Depends(db_dep)):
    rows = db.execute(
        text(
            "select id, display_name, email, auth_provider, is_guest, created_at, last_seen_at "
            "from users order by created_at desc limit 100"
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
        }
        for r in rows
    ]
    return {'ok': True, 'data': {'users': users}}


@router.get('/scan-jobs')
def list_scan_jobs(db: OrmSession = Depends(db_dep)):
    rows = db.execute(
        text(
            "select id, user_id, status, error_code, created_at, updated_at "
            "from scan_jobs order by created_at desc limit 100"
        )
    )
    jobs = [
        {
            'id': r[0],
            'userId': r[1],
            'status': r[2],
            'errorCode': r[3],
            'createdAt': r[4].isoformat() if r[4] else None,
            'updatedAt': r[5].isoformat() if r[5] else None,
        }
        for r in rows
    ]
    return {'ok': True, 'data': {'jobs': jobs}}


@router.get('/ads/slots')
def list_ad_slots(db: OrmSession = Depends(db_dep)):
    rows = db.execute(
        text(
            "select id, slot_key, placement_type, status, created_at, updated_at "
            "from ad_slots order by created_at desc limit 100"
        )
    )
    slots = [
        {
            'id': r[0],
            'slotKey': r[1],
            'placementType': r[2],
            'status': r[3],
            'createdAt': r[4].isoformat() if r[4] else None,
            'updatedAt': r[5].isoformat() if r[5] else None,
        }
        for r in rows
    ]
    return {'ok': True, 'data': {'slots': slots}}


@router.get('/branding')
def admin_branding(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': get_branding(db)}


@router.put('/branding')
def update_branding(payload: BrandingRequest, db: OrmSession = Depends(db_dep)):
    data = save_branding(db, payload.model_dump())
    return {'ok': True, 'data': data}


@router.get('/config')
def admin_config(db: OrmSession = Depends(db_dep)):
    return {
        'ok': True,
        'data': {
            'remoteScan': settings.remote_scan_enabled,
            'adsEnabled': settings.ads_enabled,
            'storageRoot': settings.storage_root,
            'apiBase': settings.api_base_url,
            'branding': get_branding(db),
        },
    }
