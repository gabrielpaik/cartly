from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..deps import admin_token_dep, db_dep
from ..schemas.push import AdminPushBroadcastRequest
from ..services.push_service import create_push_campaign, get_push_runtime_status, list_push_campaigns, list_push_devices
from .admin_common import ADMIN_ROUTE_DEP

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/push/status')
def admin_push_status(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': get_push_runtime_status(db)}


@router.get('/push/devices')
def admin_push_devices(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': {'devices': list_push_devices(db)}}


@router.get('/push/campaigns')
def admin_push_campaigns(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': {'campaigns': list_push_campaigns(db)}}


@router.post('/push/broadcast')
def admin_push_broadcast(
    payload: AdminPushBroadcastRequest,
    admin=Depends(admin_token_dep),
    db: OrmSession = Depends(db_dep),
):
    data = create_push_campaign(
        db,
        kind=payload.kind,
        audience=payload.audience,
        title=payload.title,
        message=payload.message,
        target_tab=payload.targetTab,
        target_url=payload.targetUrl,
        requested_by=admin.token[-8:],
        requested_by_source=admin.source,
    )
    return {'ok': True, 'data': data}
