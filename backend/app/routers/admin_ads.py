from typing import Optional

from fastapi import APIRouter, Depends, File, Query, Response, UploadFile
from sqlalchemy.orm import Session as OrmSession

from ..core.storage_paths import ads_assets_dir
from ..deps import db_dep
from ..schemas.ad_slot import AdSlotUpdateRequest
from ..services.ad_slot_service import (
    export_ad_campaign_xlsx,
    export_ad_campaigns_xlsx,
    get_ad_performance_summary,
    get_ad_slot_workspace,
    list_ad_campaigns,
    list_ad_slots,
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
