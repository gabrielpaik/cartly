from fastapi import APIRouter

from ..schemas.cart import CreateCartRequest

router = APIRouter()


@router.get('')
def list_carts():
    return {'ok': True, 'data': {'carts': []}}


@router.post('')
def create_cart(payload: CreateCartRequest):
    return {'ok': True, 'data': {'cart': {'id': 'cart_placeholder'}}}


@router.get('/{cart_id}')
def get_cart(cart_id: str):
    return {'ok': True, 'data': {'cart': {'id': cart_id}}}


@router.patch('/{cart_id}')
def update_cart(cart_id: str):
    return {'ok': True, 'data': {'cart': {'id': cart_id, 'updated': True}}}


@router.delete('/{cart_id}')
def delete_cart(cart_id: str):
    return {'ok': True, 'data': {'deleted': True, 'cartId': cart_id}}
