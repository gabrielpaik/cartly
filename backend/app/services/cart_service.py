import csv
import io
from datetime import date, datetime, timedelta
from typing import Iterable, Optional

GUEST_CART_RETENTION_DAYS = 14

from openpyxl import Workbook
from openpyxl.styles import Font
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session as OrmSession, selectinload

from ..db.models import Cart, CartItem, User


_CartUserType = str


def _active_cart_stmt(include_deleted: bool = False):
    stmt = select(Cart).options(selectinload(Cart.items))
    if not include_deleted:
        stmt = stmt.where(Cart.deleted_at.is_(None))
    return stmt


def _parse_saved_date(value: Optional[str]) -> Optional[date]:
    if value is None:
        return None
    trimmed = value.strip()
    if not trimmed:
        return None
    try:
        return date.fromisoformat(trimmed)
    except ValueError:
        return None


def _apply_cart_filters(
    stmt,
    *,
    query: Optional[str] = None,
    saved_date_from: Optional[str] = None,
    saved_date_to: Optional[str] = None,
    user_type: _CartUserType = 'all',
):
    needs_user_join = user_type in {'member', 'guest'}
    trimmed_query = (query or '').strip()
    if trimmed_query:
        needs_user_join = True

    if needs_user_join:
        stmt = stmt.outerjoin(User, Cart.user_id == User.id)

    if trimmed_query:
        pattern = f'%{trimmed_query}%'
        stmt = stmt.where(
            or_(
                Cart.id.ilike(pattern),
                Cart.title.ilike(pattern),
                User.display_name.ilike(pattern),
                User.email.ilike(pattern),
            )
        )

    start = _parse_saved_date(saved_date_from)
    if start is not None:
        stmt = stmt.where(Cart.saved_date >= start)

    end = _parse_saved_date(saved_date_to)
    if end is not None:
        stmt = stmt.where(Cart.saved_date <= end)

    if user_type == 'member':
        stmt = stmt.where(User.is_guest.is_(False))
    elif user_type == 'guest':
        stmt = stmt.where(User.is_guest.is_(True))
    elif user_type == 'anonymous':
        stmt = stmt.where(Cart.user_id.is_(None))

    return stmt


def _serialize_cart_item(item: CartItem) -> dict:
    return {
        'id': item.id,
        'scanResultId': item.scan_job_id,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'source': item.source,
        'createdAt': item.created_at.isoformat() if item.created_at else None,
        'updatedAt': item.updated_at.isoformat() if item.updated_at else None,
    }


def _serialize_cart(cart: Cart, include_items: bool = True, user: Optional[User] = None) -> dict:
    is_member_cart = user is not None and not user.is_guest
    expires_at = None if is_member_cart else cart.expires_at
    is_expired = expires_at is not None and expires_at <= datetime.utcnow()
    data = {
        'id': cart.id,
        'userId': cart.user_id,
        'sourceCartId': cart.source_cart_id,
        'title': cart.title,
        'status': cart.status,
        'savedDate': cart.saved_date.isoformat() if cart.saved_date else None,
        'totalPrice': cart.total_price_cached,
        'totalCount': cart.total_count_cached,
        'createdAt': cart.created_at.isoformat() if cart.created_at else None,
        'updatedAt': cart.updated_at.isoformat() if cart.updated_at else None,
        'deletedAt': cart.deleted_at.isoformat() if cart.deleted_at else None,
        'expiresAt': expires_at.isoformat() if expires_at else None,
        'isExpired': is_expired,
        'retentionExtensionCount': 0 if is_member_cart else int(cart.retention_extension_count or 0),
        'canExtendRetention': False if is_member_cart else expires_at is not None,
    }
    if user is not None:
        data['user'] = {
            'id': user.id,
            'displayName': user.display_name,
            'guestCode': user.guest_code,
            'email': user.email,
            'isGuest': user.is_guest,
            'provider': user.auth_provider,
        }
    if include_items:
        data['items'] = [_serialize_cart_item(item) for item in cart.items]
    return data


def _apply_cart_items(cart: Cart, items: Iterable[dict]) -> None:
    cart.items.clear()

    total_price = 0
    total_count = 0
    for item in items:
        quantity = max(int(item.get('quantity') or 1), 1)
        price = int(item['price'])
        cart_item = CartItem(
            scan_job_id=item.get('scanResultId'),
            name=str(item['name']).strip(),
            price=price,
            quantity=quantity,
            source='scan' if item.get('scanResultId') else 'manual',
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow(),
        )
        cart.items.append(cart_item)
        total_count += quantity
        total_price += price * quantity

    cart.total_count_cached = total_count
    cart.total_price_cached = total_price
    cart.updated_at = datetime.utcnow()


def _create_snapshot(db: OrmSession, user_id: str, payload: dict, source_cart_id: Optional[str] = None) -> Cart:
    cart = Cart(
        user_id=user_id,
        source_cart_id=source_cart_id,
        title=(payload.get('title') or '').strip() or None,
        status='saved',
        saved_date=date.today(),
        total_price_cached=0,
        total_count_cached=0,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
        deleted_at=None,
    )
    _apply_cart_items(cart, payload.get('items') or [])
    db.add(cart)
    db.commit()
    db.refresh(cart)
    return db.scalar(select(Cart).options(selectinload(Cart.items)).where(Cart.id == cart.id)) or cart


def create_cart(db: OrmSession, user_id: str, payload: dict, *, is_guest: bool = False) -> Cart:
    cart = _create_snapshot(db, user_id, payload)
    if is_guest:
        cart.expires_at = datetime.utcnow() + timedelta(days=GUEST_CART_RETENTION_DAYS)
        cart.retention_extension_count = 0
        db.add(cart)
        db.commit()
        db.refresh(cart)
    return cart


def list_user_carts(db: OrmSession, user_id: str, limit: int = 100) -> list[Cart]:
    stmt = (
        _active_cart_stmt()
        .where(Cart.user_id == user_id)
        .order_by(Cart.created_at.desc())
        .limit(limit)
    )
    return list(db.scalars(stmt).all())


def get_user_cart(db: OrmSession, cart_id: str, user_id: str) -> Optional[Cart]:
    stmt = _active_cart_stmt().where(Cart.id == cart_id, Cart.user_id == user_id)
    return db.scalar(stmt)


def extend_cart_retention(db: OrmSession, cart: Cart, *, days: int = GUEST_CART_RETENTION_DAYS) -> Cart:
    now = datetime.utcnow()
    base = cart.expires_at if cart.expires_at and cart.expires_at > now else now
    cart.expires_at = base + timedelta(days=days)
    cart.retention_extension_count = int(cart.retention_extension_count or 0) + 1
    db.add(cart)
    db.commit()
    db.refresh(cart)
    return cart


def update_cart(db: OrmSession, cart: Cart, payload: dict) -> Cart:
    next_payload = {
        'title': payload.get('title', cart.title),
        'items': payload.get('items') if payload.get('items') is not None else [
            {
                'scanResultId': item.scan_job_id,
                'name': item.name,
                'price': item.price,
                'quantity': item.quantity,
            }
            for item in cart.items
        ],
    }
    return _create_snapshot(db, cart.user_id or '', next_payload, source_cart_id=cart.id)


def delete_cart(db: OrmSession, cart: Cart) -> None:
    cart.status = 'deleted'
    cart.deleted_at = datetime.utcnow()
    cart.updated_at = datetime.utcnow()
    db.add(cart)
    db.commit()


def _load_users_for_carts(db: OrmSession, carts: list[Cart]) -> dict[str, User]:
    user_ids = sorted({cart.user_id for cart in carts if cart.user_id})
    if not user_ids:
        return {}
    users = db.scalars(select(User).where(User.id.in_(user_ids))).all()
    return {user.id: user for user in users}


def _cart_export_rows(carts: list[Cart], users_by_id: dict[str, User]) -> list[list[object]]:
    rows: list[list[object]] = []
    for cart in carts:
        user = users_by_id.get(cart.user_id or '')
        for item in cart.items:
            rows.append([
                cart.saved_date.isoformat() if cart.saved_date else '',
                cart.created_at.isoformat() if cart.created_at else '',
                cart.id,
                cart.source_cart_id or '',
                cart.title or '',
                cart.status,
                user.id if user else (cart.user_id or ''),
                user.display_name if user else '',
                user.email if user and user.email else '',
                user.auth_provider if user else '',
                'true' if user and user.is_guest else 'false',
                cart.total_count_cached,
                cart.total_price_cached,
                item.id,
                item.name,
                item.price,
                item.quantity,
                item.price * item.quantity,
                item.source,
                item.scan_job_id or '',
            ])
    return rows


def list_carts_admin(
    db: OrmSession,
    limit: int = 100,
    *,
    query: Optional[str] = None,
    saved_date_from: Optional[str] = None,
    saved_date_to: Optional[str] = None,
    user_type: _CartUserType = 'all',
) -> dict:
    filtered_stmt = _apply_cart_filters(
        _active_cart_stmt(),
        query=query,
        saved_date_from=saved_date_from,
        saved_date_to=saved_date_to,
        user_type=user_type,
    )
    all_filtered_carts = list(db.scalars(filtered_stmt.order_by(Cart.created_at.desc())).all())
    carts = all_filtered_carts[:limit]
    users_by_id = _load_users_for_carts(db, all_filtered_carts)

    total_carts = len(all_filtered_carts)
    member_carts = sum(1 for cart in all_filtered_carts if (users_by_id.get(cart.user_id or '') and not users_by_id[cart.user_id or ''].is_guest))
    guest_carts = sum(1 for cart in all_filtered_carts if (users_by_id.get(cart.user_id or '') and users_by_id[cart.user_id or ''].is_guest))
    anonymous_carts = sum(1 for cart in all_filtered_carts if not cart.user_id)
    avg_cart_value = round(sum(cart.total_price_cached for cart in all_filtered_carts) / total_carts) if total_carts else 0
    avg_item_count = round(sum(cart.total_count_cached for cart in all_filtered_carts) / total_carts, 1) if total_carts else 0.0

    return {
        'summary': {
            'totalCarts': int(total_carts),
            'memberCarts': int(member_carts),
            'guestCarts': int(guest_carts),
            'anonymousCarts': int(anonymous_carts),
            'avgCartValue': int(avg_cart_value),
            'avgItemCount': avg_item_count,
        },
        'filters': {
            'query': (query or '').strip(),
            'savedDateFrom': saved_date_from or '',
            'savedDateTo': saved_date_to or '',
            'userType': user_type,
        },
        'carts': [
            _serialize_cart(cart, include_items=True, user=users_by_id.get(cart.user_id or ''))
            for cart in carts
        ],
    }


def export_carts_admin_csv(
    db: OrmSession,
    *,
    query: Optional[str] = None,
    saved_date_from: Optional[str] = None,
    saved_date_to: Optional[str] = None,
    user_type: _CartUserType = 'all',
) -> str:
    carts = list(
        db.scalars(
            _apply_cart_filters(
                _active_cart_stmt(),
                query=query,
                saved_date_from=saved_date_from,
                saved_date_to=saved_date_to,
                user_type=user_type,
            ).order_by(Cart.created_at.desc())
        ).all()
    )
    users_by_id = _load_users_for_carts(db, carts)

    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow([
        'saved_date',
        'saved_at',
        'cart_id',
        'source_cart_id',
        'cart_title',
        'cart_status',
        'customer_id',
        'customer_name',
        'customer_email',
        'auth_provider',
        'is_guest',
        'cart_total_count',
        'cart_total_price',
        'item_id',
        'item_name',
        'item_price',
        'item_quantity',
        'item_total',
        'item_source',
        'scan_result_id',
    ])
    writer.writerows(_cart_export_rows(carts, users_by_id))
    return buffer.getvalue()


def export_carts_admin_xlsx(
    db: OrmSession,
    *,
    query: Optional[str] = None,
    saved_date_from: Optional[str] = None,
    saved_date_to: Optional[str] = None,
    user_type: _CartUserType = 'all',
) -> bytes:
    carts = list(
        db.scalars(
            _apply_cart_filters(
                _active_cart_stmt(),
                query=query,
                saved_date_from=saved_date_from,
                saved_date_to=saved_date_to,
                user_type=user_type,
            ).order_by(Cart.created_at.desc())
        ).all()
    )
    users_by_id = _load_users_for_carts(db, carts)

    workbook = Workbook()
    sheet = workbook.active
    sheet.title = 'Saved Carts'

    headers = [
        'saved_date',
        'saved_at',
        'cart_id',
        'source_cart_id',
        'cart_title',
        'cart_status',
        'customer_id',
        'customer_name',
        'customer_email',
        'auth_provider',
        'is_guest',
        'cart_total_count',
        'cart_total_price',
        'item_id',
        'item_name',
        'item_price',
        'item_quantity',
        'item_total',
        'item_source',
        'scan_result_id',
    ]
    sheet.append(headers)
    for cell in sheet[1]:
        cell.font = Font(bold=True)

    for row in _cart_export_rows(carts, users_by_id):
        sheet.append(row)

    sheet.freeze_panes = 'A2'
    for column in sheet.columns:
        max_length = max(len(str(cell.value or '')) for cell in column)
        sheet.column_dimensions[column[0].column_letter].width = min(max(max_length + 2, 12), 36)

    output = io.BytesIO()
    workbook.save(output)
    return output.getvalue()


def serialize_cart(cart: Cart, user: Optional[User] = None) -> dict:
    return _serialize_cart(cart, include_items=True, user=user)
