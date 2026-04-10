from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..schemas.ad_tracking import AdClickRequest, AdImpressionRequest
from ..services.ad_slot_service import record_ad_click, record_ad_impression

router = APIRouter()


@router.post('/impressions')
def create_ad_impression(
    payload: AdImpressionRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        data = record_ad_impression(
            db,
            slot_key=payload.slotKey,
            campaign_id=payload.campaignId,
            screen_name=payload.screenName,
            user_id=getattr(current_user, 'id', None),
            creative_id=payload.creativeId,
        )
        return {'ok': True, 'data': data}
    except ValueError as err:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={'code': str(err), 'message': '광고 노출 기록 대상을 찾지 못했어'},
        )


@router.post('/clicks')
def create_ad_click(
    payload: AdClickRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    _ = current_user
    try:
        data = record_ad_click(db, impression_id=payload.impressionId)
        return {'ok': True, 'data': data}
    except ValueError as err:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={'code': str(err), 'message': '광고 클릭 기록 대상을 찾지 못했어'},
        )
