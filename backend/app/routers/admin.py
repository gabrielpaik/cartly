import subprocess
from typing import Optional
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Query, Response, UploadFile
from sqlalchemy import desc, func, select, text
from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..core.storage_paths import ads_assets_dir, branding_assets_dir, runtime_assets_root
from ..db.models import ScanFailureLog, ScanFeedback, ScanJob
from ..deps import AdminAuthContext, admin_token_dep, db_dep
from ..schemas.ad_slot import AdSlotUpdateRequest
from ..schemas.admin_ui_copy import AdminUiCopyUpdateRequest
from ..schemas.branding import BrandingRequest
from ..services.ad_slot_service import export_ad_campaign_xlsx, list_ad_campaigns, list_ad_slots, update_ad_slot
from ..services.admin_auth_service import issue_admin_session, revoke_admin_session
from ..services.admin_service import (
    dashboard_period_summary,
    dashboard_summary,
    list_dashboard_snapshots,
    refresh_dashboard_summary_snapshot,
)
from ..services.admin_ui_copy_service import get_admin_ui_copy, save_admin_ui_copy
from ..services.admin_user_service import (
    archive_legacy_guest,
    get_user_detail_with_carts,
    list_legacy_guests,
    merge_legacy_guest_into_user,
)
from ..services.branding_service import get_branding, save_branding
from ..services.cart_service import export_carts_admin_csv, export_carts_admin_xlsx, list_carts_admin
from ..services.scan_service import get_scan_job, quarantine_scan_job, retry_scan_job, validate_image_path
from ..services.storage_health import storage_health_check

router = APIRouter()
ADMIN_ROUTE_DEP = [Depends(admin_token_dep)]


def _worker_running() -> bool:
    try:
        result = subprocess.run(
            ['pgrep', '-f', 'worker_daemon.py'],
            capture_output=True,
            text=True,
            check=False,
        )
        return result.returncode == 0 and bool(result.stdout.strip())
    except Exception:
        return False


_ALLOWED_IMAGE_TYPES = {
    'image/png': '.png',
    'image/webp': '.webp',
    'image/svg+xml': '.svg',
    'image/jpeg': '.jpg',
}


def _save_asset(file: UploadFile, target_dir, public_prefix: str):
    content_type = (file.content_type or '').lower().strip()
    ext = _ALLOWED_IMAGE_TYPES.get(content_type)
    if ext is None:
        return {
            'ok': False,
            'error': {
                'code': 'UNSUPPORTED_FILE_TYPE',
                'message': 'PNG, JPG, WEBP, SVG 파일만 업로드할 수 있어',
            },
        }

    content = file.file.read()
    if len(content) > 8 * 1024 * 1024:
        return {
            'ok': False,
            'error': {
                'code': 'FILE_TOO_LARGE',
                'message': '8MB 이하 파일만 업로드할 수 있어',
            },
        }

    file_name = f'{uuid4().hex}{ext}'
    target = target_dir / file_name
    target.write_bytes(content)

    api_base = settings.api_base_url.rstrip('/')
    return {
        'ok': True,
        'data': {
            'fileName': file_name,
            'url': f'{api_base}{public_prefix}/{file_name}',
            'contentType': content_type,
            'size': len(content),
            'storagePath': str(target),
        },
    }


@router.get('/session', dependencies=ADMIN_ROUTE_DEP)
def admin_session(auth: AdminAuthContext = Depends(admin_token_dep), db: OrmSession = Depends(db_dep)):
    if auth.source == 'root_token':
        session, raw_token = issue_admin_session(db)
        return {
            'ok': True,
            'data': {
                'role': 'admin',
                'mode': 'session',
                'session': {
                    'token': raw_token,
                    'expiresAt': session.expires_at.isoformat() if session.expires_at else None,
                },
            },
        }

    return {
        'ok': True,
        'data': {
            'role': 'admin',
            'mode': 'session',
        },
    }


@router.post('/logout', dependencies=ADMIN_ROUTE_DEP)
def admin_logout(auth: AdminAuthContext = Depends(admin_token_dep), db: OrmSession = Depends(db_dep)):
    if auth.source == 'admin_session':
        revoke_admin_session(db, auth.token)
    return {'ok': True, 'data': {'loggedOut': True}}


@router.get('/dashboard/summary', dependencies=ADMIN_ROUTE_DEP)
def get_dashboard_summary(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': dashboard_summary(db)}


@router.post('/dashboard/summary/refresh', dependencies=ADMIN_ROUTE_DEP)
def refresh_dashboard_summary(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': refresh_dashboard_summary_snapshot(db, source='manual')}


@router.get('/dashboard/period-summary', dependencies=ADMIN_ROUTE_DEP)
def get_dashboard_period_summary(
    period: str = Query(default='month', pattern='^(week|month|quarter|year)$'),
    db: OrmSession = Depends(db_dep),
):
    return {'ok': True, 'data': dashboard_period_summary(db, period)}


@router.get('/dashboard/snapshots', dependencies=ADMIN_ROUTE_DEP)
def get_dashboard_snapshots(limit: int = Query(default=30, ge=1, le=365), db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': {'snapshots': list_dashboard_snapshots(db, limit=limit)}}


@router.get('/users', dependencies=ADMIN_ROUTE_DEP)
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


@router.get('/scan-jobs', dependencies=ADMIN_ROUTE_DEP)
def list_scan_jobs(db: OrmSession = Depends(db_dep)):
    jobs = [
        {
            'id': job.id,
            'userId': job.user_id,
            'status': job.status,
            'errorCode': job.error_code,
            'errorMessage': job.error_message,
            'createdAt': job.created_at.isoformat() if job.created_at else None,
            'updatedAt': job.updated_at.isoformat() if job.updated_at else None,
        }
        for job in db.scalars(select(ScanJob).order_by(ScanJob.created_at.desc()).limit(100)).all()
    ]

    jobs_total = db.scalar(select(func.count(ScanJob.id))) or 0
    queued_jobs = db.scalar(select(func.count(ScanJob.id)).where(ScanJob.status == 'queued')) or 0
    processing_jobs = db.scalar(select(func.count(ScanJob.id)).where(ScanJob.status == 'processing')) or 0
    done_jobs = db.scalar(select(func.count(ScanJob.id)).where(ScanJob.status == 'done')) or 0
    failed_jobs = db.scalar(select(func.count(ScanJob.id)).where(ScanJob.status == 'failed')) or 0
    quarantined_jobs = db.scalar(select(func.count(ScanJob.id)).where(ScanJob.status == 'quarantined')) or 0
    oldest_queued_at = db.scalar(select(func.min(ScanJob.created_at)).where(ScanJob.status == 'queued'))

    total_feedback = db.scalar(select(func.count(ScanFeedback.id))) or 0
    accepted_feedback = db.scalar(select(func.count(ScanFeedback.id)).where(ScanFeedback.accepted.is_(True))) or 0
    corrected_feedback = db.scalar(select(func.count(ScanFeedback.id)).where(ScanFeedback.accepted.is_(False))) or 0
    failure_logs = db.scalar(select(func.count(ScanFailureLog.id))) or 0

    recent_feedback = [
        {
            'id': feedback.id,
            'jobId': feedback.scan_job_id,
            'userId': feedback.user_id,
            'accepted': feedback.accepted,
            'createdAt': feedback.created_at.isoformat() if feedback.created_at else None,
        }
        for feedback in db.scalars(
            select(ScanFeedback).order_by(desc(ScanFeedback.created_at)).limit(20)
        ).all()
    ]

    recent_failures = [
        {
            'id': failure.id,
            'jobId': failure.scan_job_id,
            'userId': failure.user_id,
            'stage': failure.stage,
            'errorCode': failure.error_code,
            'errorMessage': failure.error_message,
            'createdAt': failure.created_at.isoformat() if failure.created_at else None,
        }
        for failure in db.scalars(
            select(ScanFailureLog).order_by(desc(ScanFailureLog.created_at)).limit(20)
        ).all()
    ]

    return {
        'ok': True,
        'data': {
            'summary': {
                'jobsTotal': int(jobs_total),
                'queuedJobs': int(queued_jobs),
                'processingJobs': int(processing_jobs),
                'doneJobs': int(done_jobs),
                'failedJobs': int(failed_jobs),
                'quarantinedJobs': int(quarantined_jobs),
                'oldestQueuedAt': oldest_queued_at.isoformat() if oldest_queued_at else None,
                'workerRunning': _worker_running(),
                'feedbackTotal': int(total_feedback),
                'feedbackAccepted': int(accepted_feedback),
                'feedbackCorrected': int(corrected_feedback),
                'failureLogs': int(failure_logs),
            },
            'jobs': jobs,
            'recentFeedback': recent_feedback,
            'recentFailures': recent_failures,
        },
    }


@router.post('/scan-jobs/{job_id}/retry', dependencies=ADMIN_ROUTE_DEP)
def retry_scan_job_route(job_id: str, db: OrmSession = Depends(db_dep)):
    job = get_scan_job(db, job_id)
    if job is None:
        return {'ok': False, 'error': {'code': 'JOB_NOT_FOUND', 'message': 'scan job을 찾지 못했어'}}
    if job.status not in {'failed', 'done'}:
        return {'ok': False, 'error': {'code': 'JOB_RETRY_NOT_ALLOWED', 'message': 'failed 또는 done 상태 job만 다시 돌릴 수 있어'}}

    image_error = validate_image_path(job.source_image_path or '')
    if image_error is not None:
        return {'ok': False, 'error': {'code': 'JOB_SOURCE_INVALID', 'message': image_error}}

    job = retry_scan_job(db, job)
    return {
        'ok': True,
        'data': {
            'job': {
                'id': job.id,
                'status': job.status,
                'createdAt': job.created_at.isoformat() if job.created_at else None,
                'updatedAt': job.updated_at.isoformat() if job.updated_at else None,
            }
        },
    }


@router.post('/scan-jobs/{job_id}/quarantine', dependencies=ADMIN_ROUTE_DEP)
def quarantine_scan_job_route(job_id: str, db: OrmSession = Depends(db_dep)):
    job = get_scan_job(db, job_id)
    if job is None:
        return {'ok': False, 'error': {'code': 'JOB_NOT_FOUND', 'message': 'scan job을 찾지 못했어'}}
    if job.status != 'failed':
        return {'ok': False, 'error': {'code': 'JOB_QUARANTINE_NOT_ALLOWED', 'message': 'failed 상태 job만 quarantine 할 수 있어'}}

    job = quarantine_scan_job(db, job)
    return {
        'ok': True,
        'data': {
            'job': {
                'id': job.id,
                'status': job.status,
                'createdAt': job.created_at.isoformat() if job.created_at else None,
                'updatedAt': job.updated_at.isoformat() if job.updated_at else None,
            }
        },
    }


@router.get('/users/legacy-guests', dependencies=ADMIN_ROUTE_DEP)
def admin_legacy_guests(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': list_legacy_guests(db)}


@router.post('/users/{user_id}/archive-legacy', dependencies=ADMIN_ROUTE_DEP)
def admin_archive_legacy_guest(user_id: str, db: OrmSession = Depends(db_dep)):
    result = archive_legacy_guest(db, user_id)
    if not result.get('ok'):
        return {'ok': False, 'error': {'code': result['code'], 'message': result['message']}}
    return {'ok': True, 'data': result}


@router.post('/users/{user_id}/merge-legacy', dependencies=ADMIN_ROUTE_DEP)
def admin_merge_legacy_guest(user_id: str, payload: dict, db: OrmSession = Depends(db_dep)):
    target_user_id = str(payload.get('targetUserId') or '').strip()
    result = merge_legacy_guest_into_user(db, user_id, target_user_id)
    if not result.get('ok'):
        return {'ok': False, 'error': {'code': result['code'], 'message': result['message']}}
    return {'ok': True, 'data': result}


@router.get('/users/{user_id}/carts', dependencies=ADMIN_ROUTE_DEP)
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


@router.get('/carts/export.csv', dependencies=ADMIN_ROUTE_DEP)
def admin_carts_export_csv(
    query: str = Query(default=''),
    savedDateFrom: str = Query(default=''),
    savedDateTo: str = Query(default=''),
    userType: str = Query(default='all', pattern='^(all|member|guest|anonymous)$'),
    db: OrmSession = Depends(db_dep),
):
    csv_body = export_carts_admin_csv(
        db,
        query=query,
        saved_date_from=savedDateFrom,
        saved_date_to=savedDateTo,
        user_type=userType,
    )
    return Response(
        content=csv_body,
        media_type='text/csv; charset=utf-8',
        headers={
            'Content-Disposition': 'attachment; filename="wimc-carts-export.csv"',
        },
    )


@router.get('/carts/export.xlsx', dependencies=ADMIN_ROUTE_DEP)
def admin_carts_export_xlsx(
    query: str = Query(default=''),
    savedDateFrom: str = Query(default=''),
    savedDateTo: str = Query(default=''),
    userType: str = Query(default='all', pattern='^(all|member|guest|anonymous)$'),
    db: OrmSession = Depends(db_dep),
):
    xlsx_body = export_carts_admin_xlsx(
        db,
        query=query,
        saved_date_from=savedDateFrom,
        saved_date_to=savedDateTo,
        user_type=userType,
    )
    return Response(
        content=xlsx_body,
        media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={
            'Content-Disposition': 'attachment; filename="wimc-carts-export.xlsx"',
        },
    )


@router.get('/carts', dependencies=ADMIN_ROUTE_DEP)
def admin_carts(
    limit: int = Query(default=100, ge=1, le=500),
    query: str = Query(default=''),
    savedDateFrom: str = Query(default=''),
    savedDateTo: str = Query(default=''),
    userType: str = Query(default='all', pattern='^(all|member|guest|anonymous)$'),
    db: OrmSession = Depends(db_dep),
):
    return {
        'ok': True,
        'data': list_carts_admin(
            db,
            limit=limit,
            query=query,
            saved_date_from=savedDateFrom,
            saved_date_to=savedDateTo,
            user_type=userType,
        ),
    }


@router.get('/ads/slots', dependencies=ADMIN_ROUTE_DEP)
def list_ad_slots_route(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': {'slots': list_ad_slots(db)}}


@router.put('/ads/slots/{slot_key}', dependencies=ADMIN_ROUTE_DEP)
def update_ad_slot_route(slot_key: str, payload: AdSlotUpdateRequest, db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': update_ad_slot(db, slot_key, payload.model_dump(exclude_none=True))}


@router.get('/ads/campaigns', dependencies=ADMIN_ROUTE_DEP)
def list_ad_campaigns_route(
    slotKey: Optional[str] = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    query: str = Query(default=''),
    variant: str = Query(default='all'),
    status: str = Query(default='all'),
    periodFrom: str = Query(default=''),
    periodTo: str = Query(default=''),
    db: OrmSession = Depends(db_dep),
):
    return {
        'ok': True,
        'data': {
            'campaigns': list_ad_campaigns(
                db,
                slot_key=slotKey,
                limit=limit,
                query=query,
                variant=variant,
                status=status,
                period_from=periodFrom,
                period_to=periodTo,
            )
        },
    }


@router.get('/ads/campaigns/export.xlsx', dependencies=ADMIN_ROUTE_DEP)
def export_ad_campaigns_xlsx_route(
    slotKey: Optional[str] = Query(default=None),
    limit: int = Query(default=500, ge=1, le=1000),
    query: str = Query(default=''),
    variant: str = Query(default='all'),
    status: str = Query(default='all'),
    periodFrom: str = Query(default=''),
    periodTo: str = Query(default=''),
    db: OrmSession = Depends(db_dep),
):
    body, filename = export_ad_campaigns_xlsx(
        db,
        slot_key=slotKey,
        limit=limit,
        query=query,
        variant=variant,
        status=status,
        period_from=periodFrom,
        period_to=periodTo,
    )
    return Response(
        content=body,
        media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={
            'Content-Disposition': f'attachment; filename="{filename}"',
        },
    )


@router.get('/ads/campaigns/{campaign_id}/export.xlsx', dependencies=ADMIN_ROUTE_DEP)
def export_ad_campaign_xlsx_route(campaign_id: str, db: OrmSession = Depends(db_dep)):
    body, filename = export_ad_campaign_xlsx(db, campaign_id)
    return Response(
        content=body,
        media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={
            'Content-Disposition': f'attachment; filename="{filename}"',
        },
    )


@router.post('/ads/assets', dependencies=ADMIN_ROUTE_DEP)
def upload_ad_asset(file: UploadFile = File(...)):
    return _save_asset(file, ads_assets_dir(), '/assets/ads')


@router.get('/ui-copy', dependencies=ADMIN_ROUTE_DEP)
def admin_ui_copy(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': {'values': get_admin_ui_copy(db)}}


@router.put('/ui-copy', dependencies=ADMIN_ROUTE_DEP)
def update_admin_ui_copy(payload: AdminUiCopyUpdateRequest, db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': {'values': save_admin_ui_copy(db, payload.values)}}


@router.get('/branding', dependencies=ADMIN_ROUTE_DEP)
def admin_branding(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': get_branding(db)}


@router.put('/branding', dependencies=ADMIN_ROUTE_DEP)
def update_branding(payload: BrandingRequest, db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': save_branding(db, payload.model_dump())}


@router.post('/branding/logo', dependencies=ADMIN_ROUTE_DEP)
def upload_branding_logo(file: UploadFile = File(...)):
    return _save_asset(file, branding_assets_dir(), '/assets/branding')


@router.post('/branding/splash', dependencies=ADMIN_ROUTE_DEP)
def upload_branding_splash(file: UploadFile = File(...)):
    return _save_asset(file, branding_assets_dir(), '/assets/branding')


@router.post('/branding/login-hero', dependencies=ADMIN_ROUTE_DEP)
def upload_branding_login_hero(file: UploadFile = File(...)):
    return _save_asset(file, branding_assets_dir(), '/assets/branding')


@router.get('/config', dependencies=ADMIN_ROUTE_DEP)
def admin_config(db: OrmSession = Depends(db_dep)):
    storage = storage_health_check(create_probe=False)
    return {
        'ok': True,
        'data': {
            'remoteScan': settings.remote_scan_enabled,
            'adsEnabled': settings.ads_enabled,
            'storageRoot': settings.storage_root,
            'storageWritable': storage['writable'],
            'storagePaths': storage['paths'],
            'storageErrors': storage['errors'],
            'backendRunMode': 'terminal-login-session',
            'runtimeAssetsRoot': str(runtime_assets_root()),
            'brandingAssetsDir': str(branding_assets_dir()),
            'adsAssetsDir': str(ads_assets_dir()),
            'apiBase': settings.api_base_url,
            'branding': get_branding(db),
        },
    }
