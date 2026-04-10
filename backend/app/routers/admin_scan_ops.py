from fastapi import APIRouter, Depends
from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session as OrmSession

from ..db.models import ScanFailureLog, ScanFeedback, ScanJob
from ..deps import db_dep
from ..services.scan_service import get_scan_job, quarantine_scan_job, retry_scan_job, validate_image_path
from .admin_common import ADMIN_ROUTE_DEP, worker_running

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/scan-jobs')
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
        for feedback in db.scalars(select(ScanFeedback).order_by(desc(ScanFeedback.created_at)).limit(20)).all()
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
        for failure in db.scalars(select(ScanFailureLog).order_by(desc(ScanFailureLog.created_at)).limit(20)).all()
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
                'workerRunning': worker_running(),
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
