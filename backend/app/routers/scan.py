from fastapi import APIRouter, UploadFile, File

from ..schemas.scan import ScanFeedbackRequest

router = APIRouter()


@router.post('/jobs')
def create_scan_job(image: UploadFile = File(...)):
    return {
        'ok': True,
        'data': {
            'job': {
                'id': 'job_placeholder',
                'status': 'queued',
                'createdAt': '2026-03-20T13:00:00Z',
            }
        },
    }


@router.get('/jobs/{job_id}')
def get_scan_job(job_id: str):
    return {
        'ok': True,
        'data': {
            'job': {
                'id': job_id,
                'status': 'processing',
                'errorCode': None,
                'errorMessage': None,
                'createdAt': '2026-03-20T13:00:00Z',
                'updatedAt': '2026-03-20T13:00:03Z',
            }
        },
    }


@router.get('/jobs/{job_id}/result')
def get_scan_result(job_id: str):
    return {
        'ok': True,
        'data': {
            'jobId': job_id,
            'status': 'done',
            'result': {
                'name': '커클랜드 키친타올',
                'price': 18990,
                'sku': '123456',
                'confidence': 0.82,
                'source': 'nas-ai',
                'rawText': '...',
            },
        },
    }


@router.post('/jobs/{job_id}/feedback')
def save_feedback(job_id: str, payload: ScanFeedbackRequest):
    return {'ok': True, 'data': {'saved': True, 'jobId': job_id}}
