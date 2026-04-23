from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..services.receipt_service import create_receipt_for_saved_cart, get_receipt, serialize_receipt_result, serialize_receipt_summary

router = APIRouter()


def _require_current_user(current_user):
    if current_user is None:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                'code': 'UNAUTHORIZED',
                'message': '로그인이 필요해',
            },
            headers={'WWW-Authenticate': 'Bearer'},
        )
    return current_user


@router.post('')
def create_receipt_endpoint(
    savedCartId: str = Form(...),
    image: UploadFile = File(...),
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    try:
        receipt = create_receipt_for_saved_cart(
            db=db,
            user_id=user.id,
            saved_cart_id=savedCartId,
            image_bytes=image.file.read(),
            original_filename=image.filename or 'receipt.jpg',
        )
    except ValueError as exc:
        return {
            'ok': False,
            'error': {
                'code': 'INVALID_IMAGE_UPLOAD',
                'message': str(exc),
            },
        }
    except LookupError:
        return {
            'ok': False,
            'error': {
                'code': 'CART_NOT_FOUND',
                'message': 'saved cart를 찾지 못했어',
            },
        }

    return {'ok': True, 'data': {'receipt': serialize_receipt_summary(receipt)}}


@router.get('/{receipt_id}')
def get_receipt_endpoint(
    receipt_id: str,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    receipt = get_receipt(db, receipt_id, user.id)
    if receipt is None:
        return {
            'ok': False,
            'error': {
                'code': 'RECEIPT_NOT_FOUND',
                'message': 'receipt를 찾지 못했어',
            },
        }
    return {'ok': True, 'data': {'receipt': serialize_receipt_summary(receipt)}}


@router.get('/{receipt_id}/result')
def get_receipt_result_endpoint(
    receipt_id: str,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    receipt = get_receipt(db, receipt_id, user.id)
    if receipt is None:
        return {
            'ok': False,
            'error': {
                'code': 'RECEIPT_NOT_FOUND',
                'message': 'receipt를 찾지 못했어',
            },
        }
    if receipt.status == 'failed':
        return {
            'ok': False,
            'error': {
                'code': 'RECEIPT_ANALYSIS_FAILED',
                'message': receipt.error_message or '영수증 분석에 실패했어',
            },
        }
    if receipt.status != 'ready':
        return {
            'ok': False,
            'error': {
                'code': 'RESULT_NOT_READY',
                'message': '아직 영수증 비교 결과가 준비되지 않았어',
            },
        }
    return {'ok': True, 'data': serialize_receipt_result(receipt)}
