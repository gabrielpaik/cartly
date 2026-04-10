from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session as OrmSession

from ..deps import db_dep
from ..services.cart_service import export_carts_admin_csv, export_carts_admin_xlsx, list_carts_admin
from .admin_common import ADMIN_ROUTE_DEP

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/carts/export.csv')
def admin_carts_export_csv(
    query: str = Query(default=''),
    savedDateFrom: str = Query(default=''),
    savedDateTo: str = Query(default=''),
    userType: str = Query(default='all', pattern='^(all|member|guest|anonymous)$'),
    db: OrmSession = Depends(db_dep),
):
    csv_body = export_carts_admin_csv(
        db,
        query=query,
        saved_date_from=savedDateFrom,
        saved_date_to=savedDateTo,
        user_type=userType,
    )
    return Response(
        content=csv_body,
        media_type='text/csv; charset=utf-8',
        headers={
            'Content-Disposition': 'attachment; filename="wimc-carts-export.csv"',
        },
    )


@router.get('/carts/export.xlsx')
def admin_carts_export_xlsx(
    query: str = Query(default=''),
    savedDateFrom: str = Query(default=''),
    savedDateTo: str = Query(default=''),
    userType: str = Query(default='all', pattern='^(all|member|guest|anonymous)$'),
    db: OrmSession = Depends(db_dep),
):
    xlsx_body = export_carts_admin_xlsx(
        db,
        query=query,
        saved_date_from=savedDateFrom,
        saved_date_to=savedDateTo,
        user_type=userType,
    )
    return Response(
        content=xlsx_body,
        media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={
            'Content-Disposition': 'attachment; filename="wimc-carts-export.xlsx"',
        },
    )


@router.get('/carts')
def admin_carts(
    limit: int = Query(default=100, ge=1, le=500),
    query: str = Query(default=''),
    savedDateFrom: str = Query(default=''),
    savedDateTo: str = Query(default=''),
    userType: str = Query(default='all', pattern='^(all|member|guest|anonymous)$'),
    db: OrmSession = Depends(db_dep),
):
    return {
        'ok': True,
        'data': list_carts_admin(
            db,
            limit=limit,
            query=query,
            saved_date_from=savedDateFrom,
            saved_date_to=savedDateTo,
            user_type=userType,
        ),
    }
