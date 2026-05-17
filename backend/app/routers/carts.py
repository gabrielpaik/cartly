from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..schemas.cart import CreateCartRequest, UpdateCartRequest
from ..services.cart_service import _load_users_for_carts, create_cart, delete_cart, extend_cart_retention, get_user_cart, list_user_carts, serialize_cart_with_receipt, serialize_carts_with_receipts, update_cart
from ..services.household_service import get_household_for_user

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


def _serialize_household_meta(household):
    if household is None:
        return None
    return {
        'id': household.id,
        'name': household.name,
    }


@router.get('')
def list_carts(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    carts = list_user_carts(db, user.id)
    users_by_id = _load_users_for_carts(db, carts)
    household = _serialize_household_meta(get_household_for_user(db, user.id))
    household_by_user_id = {
        cart.user_id or '': household if household is not None and cart.user_id != user.id else None
        for cart in carts
    }
    return {
        'ok': True,
        'data': {
            'carts': serialize_carts_with_receipts(
                db,
                carts,
                users_by_id=users_by_id,
                viewer_user_id=user.id,
                household_by_user_id=household_by_user_id,
            )
        },
    }


@router.post('')
def create_cart_endpoint(
    payload: CreateCartRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    cart = create_cart(db, user.id, payload.model_dump(), is_guest=user.is_guest)
    return {'ok': True, 'data': {'cart': serialize_cart_with_receipt(db, cart, user=user, viewer_user_id=user.id)}}


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
    owner = cart.user_id == user.id and user or _load_users_for_carts(db, [cart]).get(cart.user_id or '')
    household = _serialize_household_meta(get_household_for_user(db, user.id)) if cart.user_id != user.id else None
    return {'ok': True, 'data': {'cart': serialize_cart_with_receipt(db, cart, user=owner, viewer_user_id=user.id, household=household)}}


@router.patch('/{cart_id}')
def update_cart_endpoint(
    cart_id: str,
    payload: UpdateCartRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    cart = get_user_cart(db, cart_id, user.id)
    if cart is None or cart.user_id != user.id:
        return {
            'ok': False,
            'error': {
                'code': 'CART_NOT_FOUND',
                'message': '수정할 수 있는 cart를 찾지 못했어',
            },
        }
    updated = update_cart(db, cart, payload.model_dump(exclude_unset=True))
    return {'ok': True, 'data': {'cart': serialize_cart_with_receipt(db, updated, user=user, viewer_user_id=user.id)}}


@router.post('/{cart_id}/retention/extend')
def extend_cart_retention_endpoint(
    cart_id: str,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    cart = get_user_cart(db, cart_id, user.id)
    if cart is None or cart.user_id != user.id:
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

    updated = extend_cart_retention(db, cart)
    return {'ok': True, 'data': {'cart': serialize_cart_with_receipt(db, updated, user=user, viewer_user_id=user.id)}}


@router.delete('/{cart_id}')
def delete_cart_endpoint(
    cart_id: str,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    user = _require_current_user(current_user)
    cart = get_user_cart(db, cart_id, user.id)
    if cart is None or cart.user_id != user.id:
        return {
            'ok': False,
            'error': {
                'code': 'CART_NOT_FOUND',
                'message': 'cart를 찾지 못했어',
            },
        }
    delete_cart(db, cart)
    return {'ok': True, 'data': {'deleted': True, 'cartId': cart_id}}
