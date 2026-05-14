import mimetypes
from typing import Optional

from fastapi import APIRouter, Depends, Query, Response
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session as OrmSession

from ..db.models import Cart
from ..deps import db_dep
from ..services.cart_service import _load_latest_receipts_for_carts, export_carts_admin_csv, export_carts_admin_xlsx, list_carts_admin
from ..services.category_override_service import TARGET_TYPE_CART_ITEM, apply_category_override
from ..services.scan_service import validate_image_path
from .admin_common import ADMIN_ROUTE_DEP

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


class CartItemCategoryUpdateRequest(BaseModel):
    itemIds: list[str]
    category: Optional[str] = None


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
            'Content-Disposition': 'attachment; filename="cartly-carts-export.csv"',
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
            'Content-Disposition': 'attachment; filename="cartly-carts-export.xlsx"',
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


@router.post('/cart-items/category')
def admin_cart_item_category_update(
    payload: CartItemCategoryUpdateRequest,
    db: OrmSession = Depends(db_dep),
):
    try:
        updated = apply_category_override(
            db,
            target_type=TARGET_TYPE_CART_ITEM,
            target_ids=payload.itemIds,
            category=payload.category,
        )
    except ValueError as error:
        return {'ok': False, 'error': {'code': 'INVALID_CATEGORY', 'message': str(error)}}
    return {
        'ok': True,
        'data': {
            'updated': updated,
            'category': (payload.category or '').strip() or None,
        },
    }


@router.get('/carts/{cart_id}/receipt-image')
def admin_cart_receipt_image(
    cart_id: str,
    db: OrmSession = Depends(db_dep),
):
    cart = db.get(Cart, cart_id)
    if cart is None or cart.deleted_at is not None:
        return {'ok': False, 'error': {'code': 'CART_NOT_FOUND', 'message': 'saved cart를 찾지 못했어'}}

    latest_receipt = _load_latest_receipts_for_carts(db, [cart]).get(cart.id)
    if latest_receipt is None:
        return {'ok': False, 'error': {'code': 'RECEIPT_NOT_FOUND', 'message': '연결된 영수증이 없어'}}
    if not latest_receipt.image_path:
        return {'ok': False, 'error': {'code': 'RECEIPT_IMAGE_NOT_FOUND', 'message': '영수증 이미지를 찾지 못했어'}}

    image_error = validate_image_path(latest_receipt.image_path)
    if image_error is not None:
        return {'ok': False, 'error': {'code': 'RECEIPT_IMAGE_INVALID', 'message': image_error}}

    media_type = mimetypes.guess_type(latest_receipt.image_path)[0] or 'image/jpeg'
    return FileResponse(latest_receipt.image_path, media_type=media_type)
