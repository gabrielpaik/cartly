from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session as OrmSession

from ..deps import db_dep
from ..services.admin_service import (
    dashboard_period_summary,
    dashboard_summary,
    list_dashboard_snapshots,
    refresh_dashboard_summary_snapshot,
)
from .admin_common import ADMIN_ROUTE_DEP

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/dashboard/summary')
def get_dashboard_summary(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': dashboard_summary(db)}


@router.post('/dashboard/summary/refresh')
def refresh_dashboard_summary(db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': refresh_dashboard_summary_snapshot(db, source='manual')}


@router.get('/dashboard/period-summary')
def get_dashboard_period_summary(
    period: str = Query(default='month', pattern='^(week|month|quarter|year)$'),
    db: OrmSession = Depends(db_dep),
):
    return {'ok': True, 'data': dashboard_period_summary(db, period)}


@router.get('/dashboard/snapshots')
def get_dashboard_snapshots(limit: int = Query(default=30, ge=1, le=365), db: OrmSession = Depends(db_dep)):
    return {'ok': True, 'data': {'snapshots': list_dashboard_snapshots(db, limit=limit)}}
