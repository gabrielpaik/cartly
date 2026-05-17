from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..services.household_current_cart_service import (
    add_item,
    clear_current_cart,
    delete_item,
    get_current_cart_state,
    update_item,
)
from ..services.household_service import (
    HouseholdError,
    ensure_member_can_use_household,
    generate_invite_code,
    join_household_by_invite_code,
    leave_household,
    serialize_household_state,
)

router = APIRouter()


def _error(exc: HouseholdError):
    return {'ok': False, 'error': {'code': exc.code, 'message': exc.message}}


@router.get('/me')
def get_household_me(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': serialize_household_state(db, user)}


@router.post('/invite-code')
def create_invite_code(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
        generate_invite_code(db, user)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': serialize_household_state(db, user)}


class JoinHouseholdRequest(BaseModel):
    inviteCode: str


@router.post('/join')
def join_household(
    payload: JoinHouseholdRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
        join_household_by_invite_code(db, user, payload.inviteCode)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': serialize_household_state(db, user)}


@router.post('/leave')
def leave_household_route(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
        leave_household(db, user)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': serialize_household_state(db, user)}


class HouseholdCurrentCartItemRequest(BaseModel):
    id: Optional[str] = None
    name: str
    price: int
    quantity: int = 1
    source: Optional[str] = None
    scanResultId: Optional[str] = None
    originalName: Optional[str] = None


class HouseholdCurrentCartItemPatchRequest(BaseModel):
    name: Optional[str] = None
    price: Optional[int] = None
    quantity: Optional[int] = None
    source: Optional[str] = None
    scanResultId: Optional[str] = None
    originalName: Optional[str] = None


@router.get('/current-cart')
def get_household_current_cart(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': get_current_cart_state(db, user)}


@router.post('/current-cart/items')
def add_household_current_cart_item(
    payload: HouseholdCurrentCartItemRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
        cart = add_item(db, user, payload.model_dump())
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': {'cart': cart}}


@router.patch('/current-cart/items/{item_id}')
def update_household_current_cart_item(
    item_id: str,
    payload: HouseholdCurrentCartItemPatchRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
        cart = update_item(db, user, item_id, payload.model_dump(exclude_unset=True))
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': {'cart': cart}}


@router.delete('/current-cart/items/{item_id}')
def delete_household_current_cart_item(
    item_id: str,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
        cart = delete_item(db, user, item_id)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': {'cart': cart}}


@router.delete('/current-cart')
def clear_household_current_cart(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
        cart = clear_current_cart(db, user)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': {'cart': cart}}
