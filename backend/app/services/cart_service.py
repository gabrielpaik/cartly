import csv
import io
import os
from datetime import date, datetime, timedelta
from typing import Iterable, Optional

GUEST_CART_RETENTION_DAYS = 14
PURCHASE_COMPLETION_WINDOW = timedelta(days=2)

from openpyxl import Workbook
from openpyxl.styles import Font
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session as OrmSession, selectinload

from ..db.models import Cart, CartItem, Receipt, User
from .category_override_service import TARGET_TYPE_CART_ITEM, TARGET_TYPE_SCAN_JOB, load_category_overrides, override_to_category_meta
from .scan_category_service import infer_large_category


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


def _load_category_override_maps_for_carts(db: OrmSession, carts: list[Cart]) -> tuple[dict[str, object], dict[str, object]]:
    item_ids = [item.id for cart in carts for item in cart.items if item.id]
    scan_job_ids = [item.scan_job_id for cart in carts for item in cart.items if item.scan_job_id]
    item_overrides = load_category_overrides(db, target_type=TARGET_TYPE_CART_ITEM, target_ids=item_ids)
    scan_job_overrides = load_category_overrides(db, target_type=TARGET_TYPE_SCAN_JOB, target_ids=scan_job_ids)
    return item_overrides, scan_job_overrides



def _serialize_cart_item(
    item: CartItem,
    *,
    cart_item_overrides_by_id: Optional[dict[str, object]] = None,
    scan_job_overrides_by_id: Optional[dict[str, object]] = None,
) -> dict:
    item_override = override_to_category_meta((cart_item_overrides_by_id or {}).get(item.id or ''))
    scan_job_override = override_to_category_meta((scan_job_overrides_by_id or {}).get(item.scan_job_id or ''))
    stored_meta = None
    if item.category_label:
        stored_meta = {
            'naverLargeCategory': item.category_label,
            'naverCategoryPath': item.category_label,
            'categorySource': item.category_source or 'customer-manual-v1',
        }
    category_meta = item_override or stored_meta or scan_job_override or infer_large_category(item.name, item.original_name, item.scan_job_id)
    return {
        'id': item.id,
        'scanResultId': item.scan_job_id,
        'name': item.name,
        'originalName': item.original_name,
        'originalPrice': item.original_price,
        'categoryLabel': item.category_label,
        'categorySource': item.category_source,
        'price': item.price,
        'quantity': item.quantity,
        'source': item.source,
        'categoryMeta': category_meta,
        'createdAt': item.created_at.isoformat() if item.created_at else None,
        'updatedAt': item.updated_at.isoformat() if item.updated_at else None,
    }


def _load_latest_receipts_for_carts(db: OrmSession, carts: list[Cart]) -> dict[str, Receipt]:
    cart_ids = [cart.id for cart in carts if cart.id]
    if not cart_ids:
        return {}

    source_by_cart_id: dict[str, Optional[str]] = {
        cart.id: cart.source_cart_id for cart in carts if cart.id
    }
    pending_parent_ids = {
        source_cart_id
        for source_cart_id in source_by_cart_id.values()
        if source_cart_id and source_cart_id not in source_by_cart_id
    }

    while pending_parent_ids:
        parent_rows = db.execute(
            select(Cart.id, Cart.source_cart_id).where(Cart.id.in_(pending_parent_ids))
        ).all()
        if not parent_rows:
            break

        next_pending_parent_ids: set[str] = set()
        for parent_id, source_cart_id in parent_rows:
            source_by_cart_id[parent_id] = source_cart_id
            if source_cart_id and source_cart_id not in source_by_cart_id:
                next_pending_parent_ids.add(source_cart_id)
        pending_parent_ids = next_pending_parent_ids

    descendants_by_lineage_cart_id: dict[str, list[str]] = {}
    all_lineage_cart_ids: set[str] = set()

    for cart_id in cart_ids:
        lineage: list[str] = []
        visited: set[str] = set()
        current_id: Optional[str] = cart_id
        while current_id and current_id not in visited:
            visited.add(current_id)
            lineage.append(current_id)
            current_id = source_by_cart_id.get(current_id)

        for lineage_cart_id in lineage:
            descendants_by_lineage_cart_id.setdefault(lineage_cart_id, []).append(cart_id)
        all_lineage_cart_ids.update(lineage)

    if not all_lineage_cart_ids:
        return {}

    receipts = db.scalars(
        select(Receipt)
        .where(Receipt.saved_cart_id.in_(all_lineage_cart_ids))
        .order_by(Receipt.created_at.desc())
    ).all()

    latest_by_cart_id: dict[str, Receipt] = {}
    for receipt in receipts:
        for cart_id in descendants_by_lineage_cart_id.get(receipt.saved_cart_id, []):
            if cart_id not in latest_by_cart_id:
                latest_by_cart_id[cart_id] = receipt
    return latest_by_cart_id


def _serialize_receipt_status(receipt: Optional[Receipt]) -> Optional[dict]:
    if receipt is None:
        return None

    completed_at = receipt.updated_at.isoformat() if receipt.status == 'ready' and receipt.updated_at else None

    return {
        'receiptId': receipt.id,
        'receiptStatus': receipt.status,
        'merchantName': receipt.merchant_name,
        'hasReceipt': True,
        'imageAvailable': bool(receipt.image_path),
        'imagePathLabel': os.path.basename(receipt.image_path or '') if receipt.image_path else None,
        'purchasedAt': receipt.purchased_at.isoformat() if receipt.purchased_at else None,
        'currency': receipt.currency,
        'subtotal': receipt.subtotal,
        'tax': receipt.tax,
        'totalAmount': receipt.total_amount,
        'totalDiscountAmount': receipt.total_discount_amount,
        'errorMessage': receipt.error_message,
        'rawText': receipt.raw_text,
        'updatedAt': receipt.updated_at.isoformat() if receipt.updated_at else None,
        'completedAt': completed_at,
    }


def _purchase_completion_status(cart: Cart, latest_receipt: Optional[Receipt]) -> tuple[bool, Optional[datetime], Optional[str]]:
    if latest_receipt is not None and latest_receipt.status == 'ready':
        completed_at = latest_receipt.updated_at or cart.updated_at or cart.created_at
        return True, completed_at, 'receipt'

    last_touched_at = cart.updated_at or cart.created_at
    if last_touched_at is None:
        return False, None, None

    inferred_completed_at = last_touched_at + PURCHASE_COMPLETION_WINDOW
    if inferred_completed_at > datetime.utcnow():
        return False, None, None
    return True, inferred_completed_at, 'inactive_timeout'


def _serialize_cart(
    cart: Cart,
    include_items: bool = True,
    user: Optional[User] = None,
    latest_receipt: Optional[Receipt] = None,
    cart_item_overrides_by_id: Optional[dict[str, object]] = None,
    scan_job_overrides_by_id: Optional[dict[str, object]] = None,
) -> dict:
    is_member_cart = user is not None and not user.is_guest
    expires_at = None if is_member_cart else cart.expires_at
    is_expired = expires_at is not None and expires_at <= datetime.utcnow()
    purchase_completed, purchase_completed_at, purchase_completion_source = _purchase_completion_status(cart, latest_receipt)
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
        'receiptStatus': _serialize_receipt_status(latest_receipt),
        'purchaseCompleted': purchase_completed,
        'purchaseCompletedAt': purchase_completed_at.isoformat() if purchase_completed_at else None,
        'purchaseCompletionSource': purchase_completion_source,
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
        data['items'] = [
            _serialize_cart_item(
                item,
                cart_item_overrides_by_id=cart_item_overrides_by_id,
                scan_job_overrides_by_id=scan_job_overrides_by_id,
            )
            for item in cart.items
        ]
    return data


def serialize_cart_with_receipt(
    db: OrmSession,
    cart: Cart,
    *,
    include_items: bool = True,
    user: Optional[User] = None,
) -> dict:
    latest_receipt = _load_latest_receipts_for_carts(db, [cart]).get(cart.id)
    cart_item_overrides_by_id, scan_job_overrides_by_id = _load_category_override_maps_for_carts(db, [cart])
    return _serialize_cart(
        cart,
        include_items=include_items,
        user=user,
        latest_receipt=latest_receipt,
        cart_item_overrides_by_id=cart_item_overrides_by_id,
        scan_job_overrides_by_id=scan_job_overrides_by_id,
    )


def serialize_carts_with_receipts(
    db: OrmSession,
    carts: list[Cart],
    *,
    include_items: bool = True,
    user: Optional[User] = None,
) -> list[dict]:
    latest_by_cart_id = _load_latest_receipts_for_carts(db, carts)
    cart_item_overrides_by_id, scan_job_overrides_by_id = _load_category_override_maps_for_carts(db, carts)
    return [
        _serialize_cart(
            cart,
            include_items=include_items,
            user=user,
            latest_receipt=latest_by_cart_id.get(cart.id),
            cart_item_overrides_by_id=cart_item_overrides_by_id,
            scan_job_overrides_by_id=scan_job_overrides_by_id,
        )
        for cart in carts
    ]


def _apply_cart_items(cart: Cart, items: Iterable[dict]) -> None:
    cart.items.clear()

    total_price = 0
    total_count = 0
    for item in items:
        quantity = max(int(item.get('quantity') or 1), 1)
        price = int(item['price'])
        original_name = str(item.get('originalName') or '').strip() or None
        raw_original_price = item.get('originalPrice')
        original_price = int(raw_original_price) if raw_original_price not in (None, '') else None
        if original_price is not None and original_price <= price:
            original_price = None
        raw_category_label = str(item.get('categoryLabel') or '').strip() or None
        raw_category_source = str(item.get('categorySource') or '').strip() or None
        if raw_category_label is None and isinstance(item.get('categoryMeta'), dict):
            category_meta = item.get('categoryMeta') or {}
            raw_category_label = str(category_meta.get('naverLargeCategory') or category_meta.get('category') or '').strip() or None
            raw_category_source = str(category_meta.get('categorySource') or category_meta.get('source') or '').strip() or None
        persist_manual_category = raw_category_label is not None and raw_category_source in {'customer-manual-v1', 'admin-override-v1'}
        cart_item = CartItem(
            scan_job_id=item.get('scanResultId'),
            name=str(item['name']).strip(),
            original_name=original_name,
            original_price=original_price,
            category_label=raw_category_label if persist_manual_category else None,
            category_source=raw_category_source if persist_manual_category else None,
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
    cart.title = (payload.get('title') or cart.title or '').strip() or None
    next_items = payload.get('items') if payload.get('items') is not None else [
        {
            'scanResultId': item.scan_job_id,
            'name': item.name,
            'originalName': item.original_name,
            'originalPrice': item.original_price,
            'categoryLabel': item.category_label,
            'categorySource': item.category_source,
            'price': item.price,
            'quantity': item.quantity,
        }
        for item in cart.items
    ]
    _apply_cart_items(cart, next_items)
    db.add(cart)
    db.commit()
    db.refresh(cart)
    return db.scalar(select(Cart).options(selectinload(Cart.items)).where(Cart.id == cart.id)) or cart


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


def _cart_export_rows(
    carts: list[Cart],
    users_by_id: dict[str, User],
    latest_receipts_by_cart_id: dict[str, Receipt],
) -> list[list[object]]:
    rows: list[list[object]] = []
    for cart in carts:
        user = users_by_id.get(cart.user_id or '')
        purchase_completed, purchase_completed_at, purchase_completion_source = _purchase_completion_status(
            cart,
            latest_receipts_by_cart_id.get(cart.id),
        )
        for item in cart.items:
            rows.append([
                cart.saved_date.isoformat() if cart.saved_date else '',
                cart.created_at.isoformat() if cart.created_at else '',
                cart.id,
                cart.source_cart_id or '',
                cart.title or '',
                cart.status,
                'true' if purchase_completed else 'false',
                purchase_completed_at.isoformat() if purchase_completed_at else '',
                purchase_completion_source or '',
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
    latest_receipts_by_cart_id = _load_latest_receipts_for_carts(db, all_filtered_carts)
    cart_item_overrides_by_id, scan_job_overrides_by_id = _load_category_override_maps_for_carts(db, all_filtered_carts)

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
            _serialize_cart(
                cart,
                include_items=True,
                user=users_by_id.get(cart.user_id or ''),
                latest_receipt=latest_receipts_by_cart_id.get(cart.id),
                cart_item_overrides_by_id=cart_item_overrides_by_id,
                scan_job_overrides_by_id=scan_job_overrides_by_id,
            )
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
    latest_receipts_by_cart_id = _load_latest_receipts_for_carts(db, carts)

    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow([
        'saved_date',
        'saved_at',
        'cart_id',
        'source_cart_id',
        'cart_title',
        'cart_status',
        'purchase_completed',
        'purchase_completed_at',
        'purchase_completion_source',
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
    writer.writerows(_cart_export_rows(carts, users_by_id, latest_receipts_by_cart_id))
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
    latest_receipts_by_cart_id = _load_latest_receipts_for_carts(db, carts)

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
        'purchase_completed',
        'purchase_completed_at',
        'purchase_completion_source',
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

    for row in _cart_export_rows(carts, users_by_id, latest_receipts_by_cart_id):
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
