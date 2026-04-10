import json
import os
import shutil
from datetime import datetime
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..db.models import ScanJob
from .openclaw_scan_runner import OpenClawScanRunnerError, run_openclaw_scan
from .scan_service import log_scan_failure


class ScanProcessingError(Exception):
    def __init__(self, code: str, message: str, details: Optional[dict] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = details or None


def _today_bucket() -> str:
    return datetime.utcnow().strftime('%Y-%m-%d')


def _ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def _output_path(job_id: str) -> str:
    bucket = _today_bucket()
    out_dir = os.path.join(settings.storage_root, 'output', bucket)
    _ensure_dir(out_dir)
    return os.path.join(out_dir, f'{job_id}.json')


def _archive_path(job_id: str, original_path: str) -> str:
    bucket = _today_bucket()
    ext = os.path.splitext(original_path)[1] or '.jpg'
    archive_dir = os.path.join(settings.storage_root, 'archive', bucket)
    _ensure_dir(archive_dir)
    return os.path.join(archive_dir, f'{job_id}{ext}')


def _failed_output_path(job_id: str) -> str:
    bucket = _today_bucket()
    failed_dir = os.path.join(settings.storage_root, 'failed', bucket)
    _ensure_dir(failed_dir)
    return os.path.join(failed_dir, f'{job_id}.json')


def _write_json(path: str, payload: dict) -> None:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def get_next_queued_job(db: OrmSession) -> Optional[ScanJob]:
    stmt = (
        select(ScanJob)
        .where(ScanJob.status == 'queued')
        .order_by(ScanJob.created_at.asc())
        .limit(1)
    )
    return db.scalar(stmt)


def _run_openclaw(job: ScanJob) -> dict:
    # Path traversal 방어: storage_root 하위 경로만 허용
    allowed_root = os.path.realpath(settings.storage_root)
    requested_path = os.path.realpath(job.source_image_path)
    if not requested_path.startswith(allowed_root + os.sep):
        raise ScanProcessingError(
            code='INVALID_IMAGE_PATH',
            message='이미지 경로가 유효하지 않아',
        )

    try:
        scan = run_openclaw_scan(job.id, job.source_image_path)
    except OpenClawScanRunnerError as exc:
        raise ScanProcessingError(exc.code, exc.message, exc.details) from exc

    return {
        'result': {
            'name': scan.name,
            'price': scan.price,
            'sku': scan.sku,
            'confidence': scan.confidence,
            'source': scan.source,
            'rawText': scan.raw_text,
        },
        'meta': {
            'engine': 'openclaw',
            **scan.meta,
        },
    }


def process_next_job(db: OrmSession) -> Optional[ScanJob]:
    job = get_next_queued_job(db)
    if job is None:
        return None

    job.status = 'processing'
    job.started_at = datetime.utcnow()
    job.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(job)

    try:
        if not job.source_image_path or not os.path.exists(job.source_image_path):
            raise ScanProcessingError(
                code='IMAGE_NOT_FOUND',
                message='처리할 이미지를 찾지 못했어',
            )

        payload = _run_openclaw(job)

        output = {
            'jobId': job.id,
            'status': 'done',
            'createdAt': job.created_at.isoformat() if job.created_at else None,
            'finishedAt': datetime.utcnow().isoformat(),
            'result': payload['result'],
            'meta': payload.get('meta', {}),
        }
        _write_json(_output_path(job.id), output)

        if os.path.exists(job.source_image_path):
            shutil.copy2(job.source_image_path, _archive_path(job.id, job.source_image_path))

        job.status = 'done'
        job.error_code = None
        job.error_message = None
        job.finished_at = datetime.utcnow()
        job.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(job)
        return job

    except ScanProcessingError as exc:
        _write_json(
            _failed_output_path(job.id),
            {
                'jobId': job.id,
                'status': 'failed',
                'createdAt': job.created_at.isoformat() if job.created_at else None,
                'finishedAt': datetime.utcnow().isoformat(),
                'error': {'code': exc.code, 'message': exc.message},
                'debug': exc.details or {},
            },
        )
        job.status = 'failed'
        job.error_code = exc.code
        job.error_message = exc.message
        job.finished_at = datetime.utcnow()
        job.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(job)
        log_scan_failure(
            db=db,
            job_id=job.id,
            user_id=job.user_id,
            stage='openclaw',
            error_code=exc.code,
            error_message=exc.message,
            details=exc.details,
        )
        return job

    except Exception as exc:
        job.status = 'failed'
        job.error_code = 'WORKER_FAILED'
        job.error_message = str(exc)
        job.finished_at = datetime.utcnow()
        job.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(job)
        log_scan_failure(
            db=db,
            job_id=job.id,
            user_id=job.user_id,
            stage='worker_runtime',
            error_code='WORKER_FAILED',
            error_message=str(exc),
            details=None,
        )
        return job


def _find_result_path(job_id: str) -> Optional[str]:
    today_path = os.path.join(settings.storage_root, 'output', _today_bucket(), f'{job_id}.json')
    if os.path.exists(today_path):
        return today_path

    output_root = os.path.join(settings.storage_root, 'output')
    if not os.path.isdir(output_root):
        return None

    for bucket in sorted(os.listdir(output_root), reverse=True):
        path = os.path.join(output_root, bucket, f'{job_id}.json')
        if os.path.exists(path):
            return path
    return None


def read_result(job_id: str) -> Optional[dict]:
    path = _find_result_path(job_id)
    if path is None:
        return None
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)
