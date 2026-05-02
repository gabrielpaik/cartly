from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..schemas.push import PushDeviceRegisterRequest
from ..services.push_service import get_push_runtime_status, register_push_device

router = APIRouter()


@router.get('/status')
def push_status(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': get_push_runtime_status(db)}


@router.post('/devices')
def register_device(
    payload: PushDeviceRegisterRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    data = register_push_device(
        db,
        user_id=getattr(current_user, 'id', None),
        install_id=payload.installId,
        platform=payload.platform,
        push_provider=payload.pushProvider,
        push_token=payload.pushToken,
        notifications_enabled=payload.notificationsEnabled,
        app_version=payload.appVersion,
        locale=payload.locale,
        debug_info=payload.debugInfo,
    )
    return {'ok': True, 'data': data}
