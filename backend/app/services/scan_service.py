import os
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..db.models import ScanJob


def _today_bucket() -> str:
    return datetime.utcnow().strftime('%Y-%m-%d')


def _ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def create_scan_job(db: OrmSession, user_id: Optional[str], session_id: Optional[str], image_bytes: bytes, original_filename: str) -> ScanJob:
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
