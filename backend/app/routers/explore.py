from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..services.coupang_runtime_service import get_coupang_runtime_status
from ..services.explore_offer_service import (
    build_coupang_offer_preview,
    resolve_coupang_redirect,
    search_naver_shopping_offers,
)

router = APIRouter()


def _require_current_user(current_user):
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                'code': 'UNAUTHORIZED',
                'message': '로그인이 필요해',
            },
            headers={'WWW-Authenticate': 'Bearer'},
        )
    return current_user


@router.get('/offers/naver-shopping')
def naver_shopping_offer_preview(
    intent_key: str = Query(alias='intentKey'),
    q: str = Query(min_length=1),
    source_type: str = Query(default='pendingReview', alias='sourceType'),
    reference_price: Optional[int] = Query(default=None, alias='referencePrice', ge=0),
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    _require_current_user(current_user)
    return {
        'ok': True,
        'data': search_naver_shopping_offers(
            intent_key=intent_key,
            query_text=q,
            source_type=source_type,
            reference_price=reference_price,
            db=db,
        ),
    }


@router.get('/offers/coupang-partners')
def coupang_partners_offer_preview(
    intent_key: str = Query(alias='intentKey'),
    q: str = Query(min_length=1),
    source_type: str = Query(default='pendingReview', alias='sourceType'),
    reference_price: Optional[int] = Query(default=None, alias='referencePrice', ge=0),
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    _require_current_user(current_user)
    runtime = get_coupang_runtime_status(db)
    return {
        'ok': True,
        'data': build_coupang_offer_preview(
            intent_key=intent_key,
            query_text=q,
            source_type=source_type,
            reference_price=reference_price,
            enabled=runtime['enabled'],
        ),
    }


@router.get('/offers/coupang-partners/deeplink')
def coupang_partners_deeplink_redirect(
    intent_key: str = Query(alias='intentKey'),
    q: str = Query(min_length=1),
    source_type: str = Query(default='pendingReview', alias='sourceType'),
    reference_price: Optional[int] = Query(default=None, alias='referencePrice', ge=0),
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    _require_current_user(current_user)
    runtime = get_coupang_runtime_status(db)
    target_url = resolve_coupang_redirect(
        intent_key=intent_key,
        query_text=q,
        source_type=source_type,
        reference_price=reference_price,
        enabled=runtime['enabled'],
    )
    return RedirectResponse(url=target_url, status_code=307)
