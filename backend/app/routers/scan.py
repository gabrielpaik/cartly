from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..schemas.scan import ScanFailureRequest, ScanFeedbackRequest
from ..services.scan_service import (
    create_scan_job,
    get_scan_job,
    log_scan_failure,
    save_scan_feedback,
    validate_image_bytes,
)
from ..services.worker_service import read_result

router = APIRouter()


@router.post('/jobs')
def create_scan_job_endpoint(
    image: UploadFile = File(...),
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    image_bytes = image.file.read()
    image_error = validate_image_bytes(image_bytes)
    if image_error is not None:
        return {
            'ok': False,
            'error': {
                'code': 'INVALID_IMAGE_UPLOAD',
                'message': image_error,
            },
        }

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

    payload = read_result(job.id)
    if payload is None:
        return {
            'ok': False,
            'error': {
                'code': 'RESULT_NOT_FOUND',
                'message': '결과 파일을 찾지 못했어',
            },
        }

    return {'ok': True, 'data': payload}


@router.post('/jobs/{job_id}/feedback')
def save_feedback(
    job_id: str,
    payload: ScanFeedbackRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    job = get_scan_job(db, job_id)
    if job is None:
        return {
            'ok': False,
            'error': {
                'code': 'JOB_NOT_FOUND',
                'message': 'scan job을 찾지 못했어',
            },
        }

    feedback = save_scan_feedback(
        db=db,
        job_id=job_id,
        user_id=getattr(current_user, 'id', None),
        accepted=payload.accepted,
        original=payload.original,
        corrected=payload.corrected,
    )
    return {
        'ok': True,
        'data': {
            'saved': True,
            'jobId': job_id,
            'feedbackId': feedback.id,
        },
    }


@router.post('/jobs/{job_id}/failures')
def save_failure_log(
    job_id: str,
    payload: ScanFailureRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    job = get_scan_job(db, job_id)
    if job is None:
        return {
            'ok': False,
            'error': {
                'code': 'JOB_NOT_FOUND',
                'message': 'scan job을 찾지 못했어',
            },
        }

    failure = log_scan_failure(
        db=db,
        job_id=job_id,
        user_id=getattr(current_user, 'id', None),
        stage=payload.stage,
        error_code=payload.errorCode,
        error_message=payload.errorMessage,
        details=payload.details,
    )
    return {
        'ok': True,
        'data': {
            'saved': True,
            'jobId': job_id,
            'failureId': failure.id,
        },
    }
