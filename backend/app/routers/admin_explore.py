from typing import Any, Dict

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..deps import db_dep
from ..services.explore_admin_service import (
    get_explore_settings,
    resolve_editorial_recommendation_item,
    save_explore_settings,
)
from .admin_common import ADMIN_ROUTE_DEP

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/explore')
def admin_explore(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': get_explore_settings(db)}


@router.put('/explore')
def update_admin_explore(payload: Dict[str, Any], db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': save_explore_settings(db, payload)}


@router.post('/explore/resolve-item')
def resolve_admin_explore_item(payload: Dict[str, Any]):
    return {'ok': True, 'data': resolve_editorial_recommendation_item(payload)}
