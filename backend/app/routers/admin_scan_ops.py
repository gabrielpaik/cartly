import json
import mimetypes
import os
from collections import Counter
from datetime import datetime, timedelta
from typing import Any, Optional

from PIL import Image
from fastapi import APIRouter, Depends
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..db.models import ScanFailureLog, ScanFeedback, ScanJob
from ..deps import db_dep
from ..services.app_copy_service import get_app_copy
from ..services.branding_service import get_branding
from ..services.category_override_service import TARGET_TYPE_SCAN_JOB, apply_category_override, load_category_overrides, override_to_category_meta
from ..services.scan_category_service import enrich_result_with_category
from ..services.scan_service import get_scan_job, quarantine_scan_job, retry_scan_job, validate_image_path
from ..services.worker_service import read_result
from .admin_common import ADMIN_ROUTE_DEP, worker_running

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


class ScanJobCategoryUpdateRequest(BaseModel):
    jobIds: list[str]
    category: Optional[str] = None



def _parse_json_text(value: Optional[str]) -> Optional[dict[str, Any]]:
    if not value:
        return None
    try:
        parsed = json.loads(value)
    except Exception:
        return None
    return parsed if isinstance(parsed, dict) else None


def _find_job_image_path(job: ScanJob) -> Optional[str]:
    direct = (job.source_image_path or '').strip()
    if direct and os.path.exists(direct):
        return direct

    ext = os.path.splitext(direct)[1] if direct else ''
    candidate_names = [f'{job.id}{ext}'] if ext else []
    candidate_names.extend([
        f'{job.id}.jpg',
        f'{job.id}.jpeg',
        f'{job.id}.png',
        f'{job.id}.webp',
    ])

    for root_name in ('input', 'archive'):
        root_dir = os.path.join(settings.storage_root, root_name)
        if not os.path.isdir(root_dir):
            continue
        for bucket in sorted(os.listdir(root_dir), reverse=True):
            bucket_dir = os.path.join(root_dir, bucket)
            if not os.path.isdir(bucket_dir):
                continue
            for candidate_name in candidate_names:
                candidate_path = os.path.join(bucket_dir, candidate_name)
                if os.path.exists(candidate_path):
                    return candidate_path
    return None


def _read_image_device_meta(image_path: Optional[str]) -> Optional[dict[str, str]]:
    if not image_path or not os.path.exists(image_path):
        return None
    try:
        with Image.open(image_path) as image:
            exif = image.getexif()
            if not exif:
                return None
            make = exif.get(271)
            model = exif.get(272)
            result = {}
            if isinstance(make, str) and make.strip():
                result['make'] = make.strip()
            if isinstance(model, str) and model.strip():
                result['model'] = model.strip()
            return result or None
    except Exception:
        return None


def _scan_text(scan_copy: dict[str, Any], key: str, fallback: str) -> str:
    value = scan_copy.get(key)
    if isinstance(value, str) and value.strip():
        return value.strip()
    return fallback


def _scan_nested_text(scan_copy: dict[str, Any], group: str, key: str, fallback: str) -> str:
    node = scan_copy.get(group)
    if isinstance(node, dict):
        value = node.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return fallback


def _scan_review_message(scan_copy: dict[str, Any], confidence: Any) -> str:
    if not isinstance(confidence, (int, float)):
        return _scan_nested_text(scan_copy, 'review', 'default', '인식 결과를 확인한 뒤 카트에 담아주세요.')
    if confidence >= 0.85:
        return _scan_nested_text(scan_copy, 'review', 'high', '신뢰도가 높은 결과예요. 빠르게 확인하고 담아주세요.')
    if confidence >= 0.65:
        return _scan_nested_text(scan_copy, 'review', 'medium', '한 번 확인하고 담는 걸 권장해요.')
    return _scan_nested_text(scan_copy, 'review', 'low', '확인 필요 결과예요. 수정하거나 다시 찍는 게 좋아요.')


def _user_facing_scan_error_message(scan_copy: dict[str, Any], raw_message: Optional[str]) -> str:
    message = (raw_message or '').strip()
    fallback = _scan_text(scan_copy, 'failureBody', '사진을 다시 찍거나 직접 추가해 주세요')
    if not message:
        return fallback

    lower = message.lower()
    internal_markers = (
        'openclaw',
        'runner',
        'ocr',
        'exception',
        'socket',
        'http',
        'timeout',
        'connection',
        'trace',
    )
    if any(marker in lower for marker in internal_markers):
        return fallback
    return message


def _build_customer_message(scan_copy: dict[str, Any], job: ScanJob, result_payload: Optional[dict[str, Any]]) -> str:
    if job.status == 'queued':
        return _scan_text(scan_copy, 'queued', '대기 중...')
    if job.status == 'processing':
        return _scan_text(scan_copy, 'processing', '분석 중...')
    if job.status == 'done':
        result = result_payload.get('result') if isinstance(result_payload, dict) else None
        if not isinstance(result, dict):
            return _scan_text(scan_copy, 'resultEmpty', '텍스트를 못 읽었어요. 더 가까이/선명하게 찍어봐요')
        return _scan_review_message(scan_copy, result.get('confidence'))
    return _user_facing_scan_error_message(scan_copy, job.error_message)


def _serialize_feedback(feedback: Optional[ScanFeedback]) -> Optional[dict[str, Any]]:
    if feedback is None:
        return None
    return {
        'id': feedback.id,
        'accepted': feedback.accepted,
        'createdAt': feedback.created_at.isoformat() if feedback.created_at else None,
        'original': _parse_json_text(feedback.original_json),
        'corrected': _parse_json_text(feedback.corrected_json),
    }


def _serialize_failure(failure: Optional[ScanFailureLog]) -> Optional[dict[str, Any]]:
    if failure is None:
        return None
    return {
        'id': failure.id,
        'stage': failure.stage,
        'errorCode': failure.error_code,
        'errorMessage': failure.error_message,
        'details': _parse_json_text(failure.details_json),
        'createdAt': failure.created_at.isoformat() if failure.created_at else None,
    }


def _build_reviewed_result(result: Optional[dict[str, Any]], latest_feedback: Optional[dict[str, Any]]) -> Optional[dict[str, Any]]:
    if latest_feedback:
        corrected = latest_feedback.get('corrected')
        if isinstance(corrected, dict) and corrected:
            return corrected
        original = latest_feedback.get('original')
        if isinstance(original, dict) and original:
            return original
    return result if isinstance(result, dict) else None


def _extract_category_meta(result: Optional[dict[str, Any]], reviewed_result: Optional[dict[str, Any]], result_meta: Optional[dict[str, Any]]) -> Optional[dict[str, Any]]:
    category_meta = enrich_result_with_category(reviewed_result, result_meta)
    if not category_meta or not category_meta.get('naverLargeCategory'):
        category_meta = enrich_result_with_category(result, result_meta)
    return category_meta


def _parse_created_at(value: Any) -> Optional[datetime]:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        return datetime.fromisoformat(value)
    except Exception:
        return None


def _build_scan_insights(jobs: list[dict[str, Any]]) -> dict[str, Any]:
    product_counter: Counter[str] = Counter()
    product_labels: dict[str, str] = {}
    product_categories: dict[str, str] = {}
    category_counter: Counter[str] = Counter()
    hourly_counts = [0] * 24
    weekday_counts = [0] * 7
    daily_counter: Counter[str] = Counter()

    for job in jobs:
        created_at = _parse_created_at(job.get('createdAt'))
        if created_at is not None:
            kst = created_at + timedelta(hours=9)
            hourly_counts[kst.hour] += 1
            weekday_counts[kst.weekday()] += 1
            daily_counter[kst.date().isoformat()] += 1

        result = job.get('reviewedResult') if isinstance(job.get('reviewedResult'), dict) else job.get('result') if isinstance(job.get('result'), dict) else None
        if isinstance(result, dict):
            raw_name = result.get('name')
            if isinstance(raw_name, str) and raw_name.strip():
                key = ' '.join(raw_name.split()).strip().lower()
                product_counter[key] += 1
                product_labels.setdefault(key, raw_name.strip())
                category_value = ((job.get('categoryMeta') or {}).get('naverLargeCategory') if isinstance(job.get('categoryMeta'), dict) else None) or '미분류'
                if isinstance(category_value, str):
                    product_categories.setdefault(key, category_value)

        category_value = ((job.get('categoryMeta') or {}).get('naverLargeCategory') if isinstance(job.get('categoryMeta'), dict) else None) or '미분류'
        if isinstance(category_value, str) and category_value.strip():
            category_counter[category_value.strip()] += 1

    weekday_labels = ['월', '화', '수', '목', '금', '토', '일']

    return {
        'sampleSize': len(jobs),
        'topProducts': [
            {
                'label': product_labels[key],
                'count': count,
                'category': product_categories.get(key) or '미분류',
            }
            for key, count in product_counter.most_common(10)
        ],
        'topCategories': [
            {
                'label': label,
                'count': count,
            }
            for label, count in category_counter.most_common(10)
        ],
        'hourlyActivity': [
            {
                'label': f'{hour:02d}:00',
                'count': hourly_counts[hour],
            }
            for hour in range(24)
        ],
        'weekdayActivity': [
            {
                'label': weekday_labels[index],
                'count': weekday_counts[index],
            }
            for index in range(7)
        ],
        'dailyActivity': [
            {
                'label': label,
                'count': count,
            }
            for label, count in sorted(daily_counter.items(), reverse=True)[:14]
        ],
    }


@router.get('/scan-jobs')
def list_scan_jobs(db: OrmSession = Depends(db_dep)):
    job_rows = list(db.scalars(select(ScanJob).order_by(ScanJob.created_at.desc()).limit(100)).all())
    job_ids = [job.id for job in job_rows]
    category_overrides_by_job_id = load_category_overrides(db, target_type=TARGET_TYPE_SCAN_JOB, target_ids=job_ids)

    failure_history_by_job: dict[str, list[dict[str, Any]]] = {job_id: [] for job_id in job_ids}
    feedback_history_by_job: dict[str, list[dict[str, Any]]] = {job_id: [] for job_id in job_ids}

    if job_ids:
        failure_rows = db.scalars(
            select(ScanFailureLog)
            .where(ScanFailureLog.scan_job_id.in_(job_ids))
            .order_by(desc(ScanFailureLog.created_at))
        ).all()
        for failure in failure_rows:
            failure_history_by_job.setdefault(failure.scan_job_id, []).append(_serialize_failure(failure) or {})

        feedback_rows = db.scalars(
            select(ScanFeedback)
            .where(ScanFeedback.scan_job_id.in_(job_ids))
            .order_by(desc(ScanFeedback.created_at))
        ).all()
        for feedback in feedback_rows:
            feedback_history_by_job.setdefault(feedback.scan_job_id, []).append(_serialize_feedback(feedback) or {})

    raw_branding = get_branding(db)
    app_copy = get_app_copy(db, raw_branding)
    scan_copy = app_copy.get('scan', {}) if isinstance(app_copy, dict) and isinstance(app_copy.get('scan'), dict) else {}

    jobs = []
    for job in job_rows:
        result_payload = read_result(job.id) if job.status == 'done' else None
        result = result_payload.get('result') if isinstance(result_payload, dict) and isinstance(result_payload.get('result'), dict) else None
        result_meta = result_payload.get('meta') if isinstance(result_payload, dict) and isinstance(result_payload.get('meta'), dict) else None
        image_path = _find_job_image_path(job)
        failure_history = failure_history_by_job.get(job.id, [])
        feedback_history = feedback_history_by_job.get(job.id, [])
        latest_failure = failure_history[0] if failure_history else None
        latest_feedback = feedback_history[0] if feedback_history else None
        reviewed_result = _build_reviewed_result(result, latest_feedback)
        category_meta = override_to_category_meta(category_overrides_by_job_id.get(job.id)) or _extract_category_meta(result, reviewed_result, result_meta)
        device_meta = _read_image_device_meta(image_path)
        jobs.append(
            {
                'id': job.id,
                'userId': job.user_id,
                'status': job.status,
                'errorCode': job.error_code,
                'errorMessage': job.error_message,
                'createdAt': job.created_at.isoformat() if job.created_at else None,
                'updatedAt': job.updated_at.isoformat() if job.updated_at else None,
                'startedAt': job.started_at.isoformat() if job.started_at else None,
                'finishedAt': job.finished_at.isoformat() if job.finished_at else None,
                'imageAvailable': image_path is not None,
                'imagePathLabel': os.path.basename(image_path) if image_path else None,
                'customerMessage': _build_customer_message(scan_copy, job, result_payload),
                'deviceMeta': device_meta,
                'result': result,
                'reviewedResult': reviewed_result,
                'categoryMeta': category_meta,
                'resultPayload': result_payload,
                'latestFailure': latest_failure,
                'latestFeedback': latest_feedback,
                'failureHistory': failure_history,
                'feedbackHistory': feedback_history,
            }
        )

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
                'workerRunning': worker_running(),
                'feedbackTotal': int(total_feedback),
                'feedbackAccepted': int(accepted_feedback),
                'feedbackCorrected': int(corrected_feedback),
                'failureLogs': int(failure_logs),
            },
            'jobs': jobs,
            'insights': _build_scan_insights(jobs),
        },
    }


@router.post('/scan-jobs/category')
def update_scan_job_categories(payload: ScanJobCategoryUpdateRequest, db: OrmSession = Depends(db_dep)):
    try:
        updated = apply_category_override(
            db,
            target_type=TARGET_TYPE_SCAN_JOB,
            target_ids=payload.jobIds,
            category=payload.category,
        )
    except ValueError as error:
        return {'ok': False, 'error': {'code': 'INVALID_CATEGORY', 'message': str(error)}}
    return {
        'ok': True,
        'data': {
            'updated': updated,
            'category': (payload.category or '').strip() or None,
        },
    }


@router.get('/scan-jobs/{job_id}/image')
def get_scan_job_image(job_id: str, db: OrmSession = Depends(db_dep)):
    job = get_scan_job(db, job_id)
    if job is None:
        return {'ok': False, 'error': {'code': 'JOB_NOT_FOUND', 'message': 'scan job을 찾지 못했어'}}

    image_path = _find_job_image_path(job)
    if image_path is None:
        return {'ok': False, 'error': {'code': 'JOB_IMAGE_NOT_FOUND', 'message': '원본 이미지 파일을 찾지 못했어'}}

    image_error = validate_image_path(image_path)
    if image_error is not None:
        return {'ok': False, 'error': {'code': 'JOB_IMAGE_INVALID', 'message': image_error}}

    media_type = mimetypes.guess_type(image_path)[0] or 'image/jpeg'
    return FileResponse(image_path, media_type=media_type)


@router.post('/scan-jobs/{job_id}/retry')
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


@router.post('/scan-jobs/{job_id}/quarantine')
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
