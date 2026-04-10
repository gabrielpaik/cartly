from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.orm import Session as OrmSession

from ..core.storage_paths import branding_assets_dir
from ..deps import db_dep
from ..schemas.admin_ui_copy import AdminUiCopyUpdateRequest
from ..schemas.branding import BrandingRequest
from ..services.admin_ui_copy_service import get_admin_ui_copy, save_admin_ui_copy
from ..services.branding_service import get_branding, save_branding
from .admin_common import ADMIN_ROUTE_DEP, save_asset

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/ui-copy')
def admin_ui_copy(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': {'values': get_admin_ui_copy(db)}}


@router.put('/ui-copy')
def update_admin_ui_copy(payload: AdminUiCopyUpdateRequest, db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': {'values': save_admin_ui_copy(db, payload.values)}}


@router.get('/branding')
def admin_branding(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': get_branding(db)}


@router.put('/branding')
def update_branding(payload: BrandingRequest, db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': save_branding(db, payload.model_dump())}


@router.post('/branding/logo')
def upload_branding_logo(file: UploadFile = File(...)):
    return save_asset(file, branding_assets_dir(), '/assets/branding')


@router.post('/branding/splash')
def upload_branding_splash(file: UploadFile = File(...)):
    return save_asset(file, branding_assets_dir(), '/assets/branding')


@router.post('/branding/login-hero')
def upload_branding_login_hero(file: UploadFile = File(...)):
    return save_asset(file, branding_assets_dir(), '/assets/branding')
