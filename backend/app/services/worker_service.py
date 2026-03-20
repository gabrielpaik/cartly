import json
import os
import shutil
from datetime import datetime
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..db.models import ScanJob


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


def get_next_queued_job(db: OrmSession) -> Optional[ScanJob]:
    stmt = (
        select(ScanJob)
        .where(ScanJob.status == 'queued')
        .order_by(ScanJob.created_at.asc())
        .limit(1)
    )
    return db.scalar(stmt)


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
        result = {
            'jobId': job.id,
            'status': 'done',
            'createdAt': job.created_at.isoformat() if job.created_at else None,
            'finishedAt': datetime.utcnow().isoformat(),
            'result': {
                'name': 'Sample recognized item',
                'price': 18990,
                'sku': None,
                'confidence': 0.81,
                'source': 'nas-ai',
                'rawText': 'placeholder worker output',
            },
        }
        out_path = _output_path(job.id)
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)

        if job.source_image_path and os.path.exists(job.source_image_path):
            archive_path = _archive_path(job.id, job.source_image_path)
            shutil.copy2(job.source_image_path, archive_path)

        job.status = 'done'
        job.finished_at = datetime.utcnow()
        job.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(job)
        return job
    except Exception as e:
        job.status = 'failed'
        job.error_code = 'WORKER_FAILED'
        job.error_message = str(e)
        job.finished_at = datetime.utcnow()
        job.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(job)
        return job


def read_result(job_id: str) -> Optional[dict]:
    bucket = _today_bucket()
    path = os.path.join(settings.storage_root, 'output', bucket, f'{job_id}.json')
    if not os.path.exists(path):
        return None
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)
