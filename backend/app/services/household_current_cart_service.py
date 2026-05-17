from datetime import datetime
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession, selectinload

from ..db.models import HouseholdCurrentCart, HouseholdCurrentCartItem, HouseholdMembership, User
from .household_service import HouseholdError


def _membership_for_user(db: OrmSession, user_id: str) -> Optional[HouseholdMembership]:
    return db.scalar(select(HouseholdMembership).where(HouseholdMembership.user_id == user_id))


def _serialize_item(item: HouseholdCurrentCartItem) -> dict:
    return {
        'id': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'source': item.source,
        'scanResultId': item.scan_job_id,
        'originalName': item.original_name,
        'createdAt': item.created_at.isoformat() if item.created_at else None,
        'updatedAt': item.updated_at.isoformat() if item.updated_at else None,
    }


def _serialize_cart(cart: HouseholdCurrentCart) -> dict:
    items = sorted(cart.items, key=lambda item: ((item.updated_at or item.created_at or datetime.utcnow()), item.id), reverse=True)
    return {
        'householdId': cart.household_id,
        'updatedByUserId': cart.updated_by_user_id,
        'createdAt': cart.created_at.isoformat() if cart.created_at else None,
        'updatedAt': cart.updated_at.isoformat() if cart.updated_at else None,
        'items': [_serialize_item(item) for item in items],
    }


def get_current_cart_state(db: OrmSession, user: User) -> dict:
    if user.is_guest:
        return {'shared': False, 'cart': None}
    membership = _membership_for_user(db, user.id)
    if membership is None:
        return {'shared': False, 'cart': None}
    cart = db.scalar(
        select(HouseholdCurrentCart)
        .options(selectinload(HouseholdCurrentCart.items))
        .where(HouseholdCurrentCart.household_id == membership.household_id)
    )
    if cart is None:
        return {
            'shared': True,
            'cart': {
                'householdId': membership.household_id,
                'updatedByUserId': None,
                'createdAt': None,
                'updatedAt': None,
                'items': [],
            },
        }
    return {'shared': True, 'cart': _serialize_cart(cart)}


def _ensure_current_cart(db: OrmSession, user: User) -> HouseholdCurrentCart:
    if user.is_guest:
        raise HouseholdError('HOUSEHOLD_MEMBER_ONLY', '가족 공유는 회원만 사용할 수 있어')
    membership = _membership_for_user(db, user.id)
    if membership is None:
        raise HouseholdError('HOUSEHOLD_NOT_FOUND', '가족 그룹에 참여 중이 아니야')
    cart = db.scalar(
        select(HouseholdCurrentCart)
        .options(selectinload(HouseholdCurrentCart.items))
        .where(HouseholdCurrentCart.household_id == membership.household_id)
    )
    if cart is not None:
        return cart
    cart = HouseholdCurrentCart(
        household_id=membership.household_id,
        updated_by_user_id=user.id,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(cart)
    db.commit()
    return db.scalar(
        select(HouseholdCurrentCart)
        .options(selectinload(HouseholdCurrentCart.items))
        .where(HouseholdCurrentCart.household_id == membership.household_id)
    ) or cart


def add_item(db: OrmSession, user: User, payload: dict) -> dict:
    cart = _ensure_current_cart(db, user)
    now = datetime.utcnow()
    item_id = str(payload.get('id') or '').strip() or None
    if item_id:
        existing = next((entry for entry in cart.items if entry.id == item_id), None)
        if existing is not None:
            return update_item(
                db,
                user,
                item_id,
                {
                    'name': payload.get('name'),
                    'price': payload.get('price'),
                    'quantity': payload.get('quantity'),
                    'source': payload.get('source'),
                    'scanResultId': payload.get('scanResultId'),
                    'originalName': payload.get('originalName'),
                },
            )
    item = HouseholdCurrentCartItem(
        id=item_id,
        household_id=cart.household_id,
        name=str(payload.get('name') or '').strip(),
        price=int(payload.get('price') or 0),
        quantity=max(int(payload.get('quantity') or 1), 1),
        source=str(payload.get('source') or '').strip() or None,
        scan_job_id=str(payload.get('scanResultId') or '').strip() or None,
        original_name=str(payload.get('originalName') or '').strip() or None,
        created_at=now,
        updated_at=now,
    )
    if not item.name:
        raise HouseholdError('ITEM_NAME_REQUIRED', '상품명을 입력해 줘')
    db.add(item)
    cart.updated_by_user_id = user.id
    cart.updated_at = now
    db.add(cart)
    db.commit()
    db.refresh(cart)
    return _serialize_cart(
        db.scalar(
            select(HouseholdCurrentCart)
            .options(selectinload(HouseholdCurrentCart.items))
            .where(HouseholdCurrentCart.household_id == cart.household_id)
        ) or cart
    )


def update_item(db: OrmSession, user: User, item_id: str, payload: dict) -> dict:
    cart = _ensure_current_cart(db, user)
    item = next((entry for entry in cart.items if entry.id == item_id), None)
    if item is None:
        raise HouseholdError('CURRENT_CART_ITEM_NOT_FOUND', '현재 카트 상품을 찾지 못했어')
    if 'name' in payload:
        next_name = str(payload.get('name') or '').strip()
        if not next_name:
            raise HouseholdError('ITEM_NAME_REQUIRED', '상품명을 입력해 줘')
        item.name = next_name
    if 'price' in payload:
        item.price = int(payload.get('price') or 0)
    if 'quantity' in payload:
        item.quantity = max(int(payload.get('quantity') or 1), 1)
    if 'source' in payload:
        item.source = str(payload.get('source') or '').strip() or None
    if 'scanResultId' in payload:
        item.scan_job_id = str(payload.get('scanResultId') or '').strip() or None
    if 'originalName' in payload:
        item.original_name = str(payload.get('originalName') or '').strip() or None
    now = datetime.utcnow()
    item.updated_at = now
    cart.updated_at = now
    cart.updated_by_user_id = user.id
    db.add(item)
    db.add(cart)
    db.commit()
    return _serialize_cart(
        db.scalar(
            select(HouseholdCurrentCart)
            .options(selectinload(HouseholdCurrentCart.items))
            .where(HouseholdCurrentCart.household_id == cart.household_id)
        ) or cart
    )


def delete_item(db: OrmSession, user: User, item_id: str) -> dict:
    cart = _ensure_current_cart(db, user)
    item = next((entry for entry in cart.items if entry.id == item_id), None)
    if item is None:
        raise HouseholdError('CURRENT_CART_ITEM_NOT_FOUND', '현재 카트 상품을 찾지 못했어')
    db.delete(item)
    cart.updated_at = datetime.utcnow()
    cart.updated_by_user_id = user.id
    db.add(cart)
    db.commit()
    return _serialize_cart(
        db.scalar(
            select(HouseholdCurrentCart)
            .options(selectinload(HouseholdCurrentCart.items))
            .where(HouseholdCurrentCart.household_id == cart.household_id)
        ) or cart
    )


def clear_current_cart(db: OrmSession, user: User) -> dict:
    cart = _ensure_current_cart(db, user)
    for item in list(cart.items):
        db.delete(item)
    cart.updated_at = datetime.utcnow()
    cart.updated_by_user_id = user.id
    db.add(cart)
    db.commit()
    return _serialize_cart(
        db.scalar(
            select(HouseholdCurrentCart)
            .options(selectinload(HouseholdCurrentCart.items))
            .where(HouseholdCurrentCart.household_id == cart.household_id)
        ) or cart
    )
