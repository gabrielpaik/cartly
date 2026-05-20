from typing import Optional

from fastapi import APIRouter, Depends, Query
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session as OrmSession

from ..deps import db_dep
from ..services.coupang_runtime_service import get_coupang_runtime_status
from ..services.explore_offer_service import (
    build_coupang_offer_preview,
    resolve_coupang_redirect,
    search_naver_shopping_offers,
)

router = APIRouter()


@router.get('/offers/naver-shopping')
def naver_shopping_offer_preview(
    intent_key: str = Query(alias='intentKey'),
    q: str = Query(min_length=1),
    source_type: str = Query(default='pendingReview', alias='sourceType'),
    reference_price: Optional[int] = Query(default=None, alias='referencePrice', ge=0),
):
    return {
        'ok': True,
        'data': search_naver_shopping_offers(
            intent_key=intent_key,
            query_text=q,
            source_type=source_type,
            reference_price=reference_price,
        ),
    }


@router.get('/offers/coupang-partners')
def coupang_partners_offer_preview(
    intent_key: str = Query(alias='intentKey'),
    q: str = Query(min_length=1),
    source_type: str = Query(default='pendingReview', alias='sourceType'),
    reference_price: Optional[int] = Query(default=None, alias='referencePrice', ge=0),
    db: OrmSession = Depends(db_dep),
):
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
):
    runtime = get_coupang_runtime_status(db)
    target_url = resolve_coupang_redirect(
        intent_key=intent_key,
        query_text=q,
        source_type=source_type,
        reference_price=reference_price,
        enabled=runtime['enabled'],
    )
    return RedirectResponse(url=target_url, status_code=307)
