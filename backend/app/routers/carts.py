from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..schemas.cart import CreateCartRequest, UpdateCartRequest
from ..services.cart_service import create_cart, delete_cart, extend_cart_retention, get_user_cart, list_user_carts, serialize_cart_with_receipt, serialize_carts_with_receipts, update_cart

router = APIRouter()


def _require_current_user(current_user):
    if current_user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                'code': 'UNAUTHORIZED',
                'message': '로그인이 필요해',
            },
            headers={'WWW-Authenticate': 'Bearer'},
        )
    return current_user


@router.get('')
def list_carts(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    carts = list_user_carts(db, user.id)
    return {'ok': True, 'data': {'carts': serialize_carts_with_receipts(db, carts, user=user)}}


@router.post('')
def create_cart_endpoint(
    payload: CreateCartRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    cart = create_cart(db, user.id, payload.model_dump(), is_guest=user.is_guest)
    return {'ok': True, 'data': {'cart': serialize_cart_with_receipt(db, cart, user=user)}}


@router.get('/{cart_id}')
def get_cart(
    cart_id: str,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    cart = get_user_cart(db, cart_id, user.id)
    if cart is None:
        return {
            'ok': False,
            'error': {
                'code': 'CART_NOT_FOUND',
                'message': 'cart를 찾지 못했어',
            },
        }
    return {'ok': True, 'data': {'cart': serialize_cart_with_receipt(db, cart, user=user)}}


@router.patch('/{cart_id}')
def update_cart_endpoint(
    cart_id: str,
    payload: UpdateCartRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    cart = get_user_cart(db, cart_id, user.id)
    if cart is None:
        return {
            'ok': False,
            'error': {
                'code': 'CART_NOT_FOUND',
                'message': 'cart를 찾지 못했어',
            },
        }
    updated = update_cart(db, cart, payload.model_dump(exclude_unset=True))
    return {'ok': True, 'data': {'cart': serialize_cart_with_receipt(db, updated, user=user)}}


@router.post('/{cart_id}/retention/extend')
def extend_cart_retention_endpoint(
    cart_id: str,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    cart = get_user_cart(db, cart_id, user.id)
    if cart is None:
        return {
            'ok': False,
            'error': {
                'code': 'CART_NOT_FOUND',
                'message': 'cart를 찾지 못했어',
            },
        }
    if not user.is_guest:
        return {
            'ok': False,
            'error': {
                'code': 'MEMBER_RETENTION_NOT_REQUIRED',
                'message': '회원 카트는 저장기간 연장이 필요하지 않아',
            },
        }

    # TODO: require verified rewarded-ad proof before granting extension.
    updated = extend_cart_retention(db, cart)
    return {'ok': True, 'data': {'cart': serialize_cart_with_receipt(db, updated, user=user)}}


@router.delete('/{cart_id}')
def delete_cart_endpoint(
    cart_id: str,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    cart = get_user_cart(db, cart_id, user.id)
    if cart is None:
        return {
            'ok': False,
            'error': {
                'code': 'CART_NOT_FOUND',
                'message': 'cart를 찾지 못했어',
            },
        }
    delete_cart(db, cart)
    return {'ok': True, 'data': {'deleted': True, 'cartId': cart_id}}
