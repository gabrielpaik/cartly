from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..services.scan_service import create_scan_job, get_scan_job
from ..schemas.scan import ScanFeedbackRequest

router = APIRouter()


@router.post('/jobs')
def create_scan_job_endpoint(
    image: UploadFile = File(...),
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    image_bytes = image.file.read()
    job = create_scan_job(
        db=db,
        user_id=getattr(current_user, 'id', None),
        session_id=None,
        image_bytes=image_bytes,
        original_filename=image.filename or 'upload.jpg',
    )

    return {
        'ok': True,
        'data': {
            'job': {
                'id': job.id,
                'status': job.status,
                'createdAt': job.created_at.isoformat() if job.created_at else None,
            }
        },
    }


@router.get('/jobs/{job_id}')
def get_scan_job_endpoint(job_id: str, db: OrmSession = Depends(db_dep)):
    job = get_scan_job(db, job_id)
    if job is None:
        return {
            'ok': False,
            'error': {
                'code': 'JOB_NOT_FOUND',
                'message': 'scan job을 찾지 못했어',
            },
        }

    return {
        'ok': True,
        'data': {
            'job': {
                'id': job.id,
                'status': job.status,
                'errorCode': job.error_code,
                'errorMessage': job.error_message,
                'createdAt': job.created_at.isoformat() if job.created_at else None,
                'updatedAt': job.updated_at.isoformat() if job.updated_at else None,
            }
        },
    }


@router.get('/jobs/{job_id}/result')
def get_scan_result(job_id: str, db: OrmSession = Depends(db_dep)):
    job = get_scan_job(db, job_id)
    if job is None:
        return {
            'ok': False,
            'error': {
                'code': 'JOB_NOT_FOUND',
                'message': 'scan job을 찾지 못했어',
            },
        }

    if job.status != 'done':
        return {
            'ok': False,
            'error': {
                'code': 'RESULT_NOT_READY',
                'message': '아직 분석 결과가 준비되지 않았어',
            },
        }

    return {
        'ok': True,
        'data': {
            'jobId': job.id,
            'status': job.status,
            'result': {
                'name': 'placeholder',
                'price': 0,
                'sku': None,
                'confidence': None,
                'source': 'nas-ai',
                'rawText': None,
            },
        },
    }


@router.post('/jobs/{job_id}/feedback')
def save_feedback(job_id: str, payload: ScanFeedbackRequest):
    return {'ok': True, 'data': {'saved': True, 'jobId': job_id}}
