import json
import os
import uuid
from datetime import datetime
from typing import Any, Dict, Optional

from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..db.models import ScanFailureLog, ScanFeedback, ScanJob


def _today_bucket() -> str:
    return datetime.utcnow().strftime('%Y-%m-%d')


def _ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def _write_json(path: str, payload: Dict[str, Any]) -> None:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def create_scan_job(
    db: OrmSession,
    user_id: Optional[str],
    session_id: Optional[str],
    image_bytes: bytes,
    original_filename: str,
) -> ScanJob:
    job_id = str(uuid.uuid4())
    ext = os.path.splitext(original_filename or '')[1] or '.jpg'

    bucket = _today_bucket()
    input_dir = os.path.join(settings.storage_root, 'input', bucket)
    _ensure_dir(input_dir)

    file_name = f'{job_id}{ext}'
    file_path = os.path.join(input_dir, file_name)
    with open(file_path, 'wb') as f:
        f.write(image_bytes)

    job = ScanJob(
        id=job_id,
        user_id=user_id,
        session_id=session_id,
        source_image_path=file_path,
        status='queued',
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(job)
    db.commit()
    db.refresh(job)
    return job


def get_scan_job(db: OrmSession, job_id: str) -> Optional[ScanJob]:
    return db.get(ScanJob, job_id)


def save_scan_feedback(
    db: OrmSession,
    job_id: str,
    user_id: Optional[str],
    accepted: bool,
    original: Optional[Dict[str, Any]],
    corrected: Optional[Dict[str, Any]],
) -> ScanFeedback:
    feedback = ScanFeedback(
        scan_job_id=job_id,
        user_id=user_id,
        accepted=accepted,
        original_json=json.dumps(original, ensure_ascii=False) if original is not None else None,
        corrected_json=json.dumps(corrected, ensure_ascii=False) if corrected is not None else None,
        created_at=datetime.utcnow(),
    )
    db.add(feedback)
    db.commit()
    db.refresh(feedback)

    bucket = _today_bucket()
    feedback_dir = os.path.join(settings.storage_root, 'logs', 'feedback', bucket)
    _ensure_dir(feedback_dir)
    _write_json(
        os.path.join(feedback_dir, f'{job_id}-{feedback.id}.json'),
        {
            'feedbackId': feedback.id,
            'jobId': job_id,
            'accepted': accepted,
            'original': original,
            'corrected': corrected,
            'createdAt': feedback.created_at.isoformat(),
        },
    )
    return feedback


def log_scan_failure(
    db: OrmSession,
    job_id: str,
    user_id: Optional[str],
    stage: str,
    error_code: Optional[str],
    error_message: Optional[str],
    details: Optional[Dict[str, Any]],
) -> ScanFailureLog:
    failure = ScanFailureLog(
        scan_job_id=job_id,
        user_id=user_id,
        stage=stage,
        error_code=error_code,
        error_message=error_message,
        details_json=json.dumps(details, ensure_ascii=False) if details is not None else None,
        created_at=datetime.utcnow(),
    )
    db.add(failure)
    db.commit()
    db.refresh(failure)

    bucket = _today_bucket()
    failed_dir = os.path.join(settings.storage_root, 'failed', bucket)
    logs_dir = os.path.join(settings.storage_root, 'logs', 'failures', bucket)
    _ensure_dir(failed_dir)
    _ensure_dir(logs_dir)

    _write_json(
        os.path.join(logs_dir, f'{job_id}-{failure.id}.json'),
        {
            'failureId': failure.id,
            'jobId': job_id,
            'stage': stage,
            'errorCode': error_code,
            'errorMessage': error_message,
            'details': details,
            'createdAt': failure.created_at.isoformat(),
        },
    )

    return failure
