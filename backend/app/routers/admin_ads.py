from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile, status
from sqlalchemy.orm import Session as OrmSession

from ..core.storage_paths import ads_assets_dir
from ..deps import db_dep
from ..schemas.ad_slot import AdCampaignUpsertRequest, AdSlotUpdateRequest
from ..services.ad_slot_service import (
    cancel_ad_campaign,
    create_ad_campaign,
    delete_ad_campaign,
    export_ad_campaign_csv,
    export_ad_campaign_xlsx,
    export_ad_campaigns_csv,
    export_ad_campaigns_xlsx,
    get_ad_performance_summary,
    get_ad_slot_workspace,
    list_ad_campaigns,
    list_ad_slots,
    update_ad_campaign,
    update_ad_slot,
)
from .admin_common import ADMIN_ROUTE_DEP, save_asset

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/ads/slots')
def list_ad_slots_route(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': {'slots': list_ad_slots(db)}}


@router.put('/ads/slots/{slot_key}')
def update_ad_slot_route(slot_key: str, payload: AdSlotUpdateRequest, db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': update_ad_slot(db, slot_key, payload.model_dump(exclude_none=True))}


@router.post('/ads/campaigns')
def create_ad_campaign_route(payload: AdCampaignUpsertRequest, db: OrmSession = Depends(db_dep)):
    try:
        return {'ok': True, 'data': create_ad_campaign(db, payload.model_dump())}
    except ValueError as error:
        detail = str(error)
        status_code = 404 if detail == 'slot_not_found' else 400
        raise HTTPException(status_code=status_code, detail=detail)


@router.put('/ads/campaigns/{campaign_id}')
def update_ad_campaign_route(campaign_id: str, payload: AdCampaignUpsertRequest, db: OrmSession = Depends(db_dep)):
    try:
        return {'ok': True, 'data': update_ad_campaign(db, campaign_id, payload.model_dump())}
    except ValueError as error:
        detail = str(error)
        status_code = 404 if detail in {'slot_not_found', 'campaign_not_found'} else 400
        raise HTTPException(status_code=status_code, detail=detail)


@router.post('/ads/campaigns/{campaign_id}/cancel')
def cancel_ad_campaign_route(campaign_id: str, db: OrmSession = Depends(db_dep)):
    try:
        return {'ok': True, 'data': cancel_ad_campaign(db, campaign_id)}
    except ValueError as error:
        detail = str(error)
        status_code = 404 if detail == 'campaign_not_found' else 400
        raise HTTPException(status_code=status_code, detail=detail)


@router.delete('/ads/campaigns/{campaign_id}', status_code=status.HTTP_200_OK)
def delete_ad_campaign_route(campaign_id: str, db: OrmSession = Depends(db_dep)):
    try:
        return {'ok': True, 'data': delete_ad_campaign(db, campaign_id)}
    except ValueError as error:
        detail = str(error)
        status_code = 404 if detail == 'campaign_not_found' else 400
        raise HTTPException(status_code=status_code, detail=detail)


@router.get('/ads/performance/summary')
def ad_performance_summary_route(
    slotKey: Optional[str] = Query(default=None),
    surface: str = Query(default=''),
    status: str = Query(default='all'),
    variant: str = Query(default='all'),
    periodFrom: str = Query(default=''),
    periodTo: str = Query(default=''),
    db: OrmSession = Depends(db_dep),
):
    return {
        'ok': True,
        'data': get_ad_performance_summary(
            db,
            slot_key=slotKey,
            surface=surface,
            status=status,
            variant=variant,
            period_from=periodFrom,
            period_to=periodTo,
        ),
    }


@router.get('/ads/slots/{slot_key}/workspace')
def ad_slot_workspace_route(
    slot_key: str,
    periodFrom: str = Query(default=''),
    periodTo: str = Query(default=''),
    db: OrmSession = Depends(db_dep),
):
    return {
        'ok': True,
        'data': get_ad_slot_workspace(db, slot_key, period_from=periodFrom, period_to=periodTo),
    }


@router.get('/ads/campaigns')
def list_ad_campaigns_route(
    slotKey: Optional[str] = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    query: str = Query(default=''),
    variant: str = Query(default='all'),
    status: str = Query(default='all'),
    periodFrom: str = Query(default=''),
    periodTo: str = Query(default=''),
    db: OrmSession = Depends(db_dep),
):
    return {
        'ok': True,
        'data': {
            'campaigns': list_ad_campaigns(
                db,
                slot_key=slotKey,
                limit=limit,
                query=query,
                variant=variant,
                status=status,
                period_from=periodFrom,
                period_to=periodTo,
            )
        },
    }


@router.get('/ads/campaigns/export.csv')
def export_ad_campaigns_csv_route(
    slotKey: Optional[str] = Query(default=None),
    limit: int = Query(default=500, ge=1, le=1000),
    query: str = Query(default=''),
    variant: str = Query(default='all'),
    status: str = Query(default='all'),
    periodFrom: str = Query(default=''),
    periodTo: str = Query(default=''),
    db: OrmSession = Depends(db_dep),
):
    body, filename = export_ad_campaigns_csv(
        db,
        slot_key=slotKey,
        limit=limit,
        query=query,
        variant=variant,
        status=status,
        period_from=periodFrom,
        period_to=periodTo,
    )
    return Response(
        content=body,
        media_type='text/csv; charset=utf-8',
        headers={
            'Content-Disposition': f'attachment; filename="{filename}"',
        },
    )


@router.get('/ads/campaigns/export.xlsx')
def export_ad_campaigns_xlsx_route(
    slotKey: Optional[str] = Query(default=None),
    limit: int = Query(default=500, ge=1, le=1000),
    query: str = Query(default=''),
    variant: str = Query(default='all'),
    status: str = Query(default='all'),
    periodFrom: str = Query(default=''),
    periodTo: str = Query(default=''),
    db: OrmSession = Depends(db_dep),
):
    body, filename = export_ad_campaigns_xlsx(
        db,
        slot_key=slotKey,
        limit=limit,
        query=query,
        variant=variant,
        status=status,
        period_from=periodFrom,
        period_to=periodTo,
    )
    return Response(
        content=body,
        media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={
            'Content-Disposition': f'attachment; filename="{filename}"',
        },
    )


@router.get('/ads/campaigns/{campaign_id}/export.csv')
def export_ad_campaign_csv_route(campaign_id: str, db: OrmSession = Depends(db_dep)):
    body, filename = export_ad_campaign_csv(db, campaign_id)
    return Response(
        content=body,
        media_type='text/csv; charset=utf-8',
        headers={
            'Content-Disposition': f'attachment; filename="{filename}"',
        },
    )


@router.get('/ads/campaigns/{campaign_id}/export.xlsx')
def export_ad_campaign_xlsx_route(campaign_id: str, db: OrmSession = Depends(db_dep)):
    body, filename = export_ad_campaign_xlsx(db, campaign_id)
    return Response(
        content=body,
        media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={
            'Content-Disposition': f'attachment; filename="{filename}"',
        },
    )


@router.post('/ads/assets')
def upload_ad_asset(file: UploadFile = File(...)):
    return save_asset(file, ads_assets_dir(), '/assets/ads')
