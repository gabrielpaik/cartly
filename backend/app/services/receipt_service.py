import json
import os
import re
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession, selectinload

from ..core.settings import settings
from ..db.models import Cart, Receipt, ReceiptLineItem
from .openclaw_receipt_runner import OpenClawReceiptResult, OpenClawReceiptRunnerError, run_openclaw_receipt
from .scan_service import validate_image_bytes


@dataclass
class _ReceiptItemCandidate:
    line_item: ReceiptLineItem
    normalized_name: str
    quantity: int
    unit_price: int
    final_amount: int



def _today_bucket() -> str:
    return datetime.utcnow().strftime('%Y-%m-%d')


def _ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def _write_json(path: str, payload: dict) -> None:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def _normalize_name(value: str) -> str:
    normalized = re.sub(r'[^0-9A-Za-z가-힣]+', ' ', value or '').strip().lower()
    return re.sub(r'\s+', ' ', normalized)



def _safe_datetime(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    except ValueError:
        return None
    if parsed.tzinfo is not None:
        return parsed.astimezone(timezone.utc).replace(tzinfo=None)
    return parsed


def _artifact_path(kind: str, receipt_id: str) -> str:
    bucket = _today_bucket()
    out_dir = os.path.join(settings.storage_root, 'receipts', kind, bucket)
    _ensure_dir(out_dir)
    return os.path.join(out_dir, f'{receipt_id}.json')



def _derive_final_amount(quantity: int, unit_price: int, line_amount: int, final_amount: Optional[int]) -> int:
    if final_amount is not None and final_amount != 0:
        return int(final_amount)
    if line_amount != 0:
        return int(line_amount)
    return int(unit_price) * max(quantity, 1)


def _derive_unit_price(quantity: int, unit_price: Optional[int], line_amount: int, final_amount: Optional[int]) -> int:
    if unit_price is not None and unit_price > 0:
        return int(unit_price)
    qty = max(int(quantity or 1), 1)
    basis = final_amount if final_amount not in (None, 0) else line_amount
    if basis:
        return max(int(round(basis / qty)), 0)
    return 0


def _derive_subtotal(line_items: list[ReceiptLineItem]) -> int:
    explicit = next((item.final_amount for item in line_items if item.category == 'subtotal' and item.final_amount is not None), None)
    if explicit is not None:
        return int(explicit)
    return sum(max(int(item.final_amount if item.final_amount is not None else item.line_amount), 0) for item in line_items if item.category == 'item')


def _derive_tax(line_items: list[ReceiptLineItem]) -> int:
    return sum(int(item.final_amount if item.final_amount is not None else item.line_amount) for item in line_items if item.category == 'tax')


def _derive_discount(line_items: list[ReceiptLineItem]) -> int:
    explicit = 0
    for item in line_items:
        if item.category not in {'discount', 'coupon'}:
            continue
        amount = int(item.final_amount if item.final_amount is not None else item.line_amount)
        explicit += abs(amount)
    return explicit


def _derive_total_amount(subtotal: int, tax: int, discount: int, line_items: list[ReceiptLineItem]) -> int:
    payment_amounts = [abs(int(item.final_amount if item.final_amount is not None else item.line_amount)) for item in line_items if item.category == 'payment']
    if payment_amounts:
        return max(payment_amounts)
    return max(subtotal + tax - discount, 0)


def _receipt_item_candidates(line_items: list[ReceiptLineItem]) -> list[_ReceiptItemCandidate]:
    candidates: list[_ReceiptItemCandidate] = []
    for item in line_items:
        if item.category != 'item':
            continue
        quantity = max(int(item.quantity or 1), 1)
        final_amount = _derive_final_amount(quantity, int(item.unit_price or 0), int(item.line_amount or 0), item.final_amount)
        if final_amount <= 0:
            continue
        unit_price = _derive_unit_price(quantity, item.unit_price, int(item.line_amount or 0), item.final_amount)
        candidates.append(
            _ReceiptItemCandidate(
                line_item=item,
                normalized_name=_normalize_name(item.raw_name),
                quantity=quantity,
                unit_price=unit_price,
                final_amount=final_amount,
            )
        )
    return candidates



def get_user_saved_cart(db: OrmSession, cart_id: str, user_id: str) -> Optional[Cart]:
    stmt = (
        select(Cart)
        .options(selectinload(Cart.items))
        .where(Cart.id == cart_id, Cart.user_id == user_id, Cart.status == 'saved', Cart.deleted_at.is_(None))
    )
    return db.scalar(stmt)


def _persist_receipt_analysis(
    db: OrmSession,
    *,
    receipt: Receipt,
    analysis: OpenClawReceiptResult,
) -> None:
    created_at = receipt.created_at or datetime.utcnow()
    now = datetime.utcnow()

    for existing in list(receipt.line_items):
        db.delete(existing)
    db.flush()

    persisted_line_items: list[ReceiptLineItem] = []
    for parsed in analysis.line_items:
        quantity = max(int(parsed.quantity or 1), 1) if parsed.category == 'item' else parsed.quantity
        line_item = ReceiptLineItem(
            receipt_id=receipt.id,
            raw_name=parsed.raw_name,
            normalized_name=_normalize_name(parsed.raw_name),
            quantity=quantity,
            unit_price=parsed.unit_price,
            line_amount=int(parsed.line_amount),
            final_amount=parsed.final_amount,
            category=parsed.category,
            confidence=parsed.confidence,
            created_at=created_at,
            updated_at=now,
        )
        db.add(line_item)
        db.flush()
        persisted_line_items.append(line_item)

    receipt_items = _receipt_item_candidates(persisted_line_items)
    if not receipt_items:
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_NO_ITEMS',
            message='영수증에서 실제 구매 상품 행을 찾지 못했어',
        )

    subtotal = analysis.subtotal if analysis.subtotal is not None else _derive_subtotal(persisted_line_items)
    tax = analysis.tax if analysis.tax is not None else _derive_tax(persisted_line_items)
    total_discount_amount = analysis.total_discount_amount if analysis.total_discount_amount is not None else _derive_discount(persisted_line_items)
    total_amount = analysis.total_amount if analysis.total_amount is not None else _derive_total_amount(subtotal, tax, total_discount_amount, persisted_line_items)

    receipt.status = 'ready'
    receipt.image_filename = receipt.image_filename or os.path.basename(receipt.image_path or '')
    receipt.merchant_name = analysis.merchant_name or '영수증 확인 결과'
    receipt.purchased_at = _safe_datetime(analysis.purchased_at) or receipt.purchased_at
    receipt.currency = analysis.currency or 'KRW'
    receipt.subtotal = subtotal
    receipt.tax = tax
    receipt.total_amount = total_amount
    receipt.total_discount_amount = total_discount_amount
    receipt.raw_text = analysis.raw_text
    receipt.error_message = None
    receipt.updated_at = now

    _write_json(
        _artifact_path('analysis', receipt.id),
        {
            'receiptId': receipt.id,
            'savedCartId': receipt.saved_cart_id,
            'status': receipt.status,
            'merchantName': receipt.merchant_name,
            'purchasedAt': receipt.purchased_at.isoformat() if receipt.purchased_at else None,
            'currency': receipt.currency,
            'subtotal': subtotal,
            'tax': tax,
            'totalAmount': total_amount,
            'totalDiscountAmount': total_discount_amount,
            'lineItems': [
                {
                    'id': item.id,
                    'rawName': item.raw_name,
                    'quantity': item.quantity,
                    'unitPrice': item.unit_price,
                    'lineAmount': item.line_amount,
                    'finalAmount': item.final_amount,
                    'category': item.category,
                    'confidence': item.confidence,
                }
                for item in persisted_line_items
            ],
            'meta': analysis.meta,
            'updatedAt': now.isoformat(),
        },
    )

    db.add(receipt)
    db.commit()


def _mark_receipt_failed(
    db: OrmSession,
    *,
    receipt: Receipt,
    code: str,
    message: str,
    details: Optional[dict] = None,
) -> None:
    now = datetime.utcnow()
    receipt.status = 'failed'
    receipt.error_message = message
    receipt.updated_at = now
    db.add(receipt)
    db.commit()
    _write_json(
        _artifact_path('failed', receipt.id),
        {
            'receiptId': receipt.id,
            'savedCartId': receipt.saved_cart_id,
            'status': 'failed',
            'error': {
                'code': code,
                'message': message,
                'details': details or None,
            },
            'updatedAt': now.isoformat(),
        },
    )


def create_receipt_for_saved_cart(
    db: OrmSession,
    *,
    user_id: str,
    saved_cart_id: str,
    image_bytes: bytes,
    original_filename: str,
) -> Receipt:
    image_error = validate_image_bytes(image_bytes)
    if image_error is not None:
        raise ValueError(image_error)

    cart = get_user_saved_cart(db, saved_cart_id, user_id)
    if cart is None:
        raise LookupError('SAVED_CART_NOT_FOUND')

    receipt_id = str(uuid.uuid4())
    ext = os.path.splitext(original_filename or '')[1] or '.jpg'
    bucket = _today_bucket()
    receipt_dir = os.path.join(settings.storage_root, 'receipts', bucket)
    _ensure_dir(receipt_dir)
    file_path = os.path.join(receipt_dir, f'{receipt_id}{ext}')
    with open(file_path, 'wb') as f:
        f.write(image_bytes)

    created_at = datetime.utcnow()
    receipt = Receipt(
        id=receipt_id,
        user_id=user_id,
        saved_cart_id=cart.id,
        status='processing',
        image_path=file_path,
        image_filename=original_filename or f'{receipt_id}{ext}',
        merchant_name=None,
        purchased_at=None,
        currency='KRW',
        subtotal=None,
        tax=None,
        total_amount=None,
        total_discount_amount=None,
        raw_text=None,
        error_message=None,
        created_at=created_at,
        updated_at=created_at,
    )
    db.add(receipt)
    db.commit()
    db.refresh(receipt)

    try:
        analysis = run_openclaw_receipt(receipt.id, file_path)
        _persist_receipt_analysis(db, receipt=receipt, analysis=analysis)
    except OpenClawReceiptRunnerError as exc:
        _mark_receipt_failed(db, receipt=receipt, code=exc.code, message=exc.message, details=exc.details)
    except Exception as exc:
        _mark_receipt_failed(
            db,
            receipt=receipt,
            code='RECEIPT_ANALYSIS_FAILED',
            message='영수증 분석 중 알 수 없는 오류가 발생했어',
            details={'exception': str(exc)},
        )

    return get_receipt(db, receipt.id, user_id) or receipt


def get_receipt(db: OrmSession, receipt_id: str, user_id: str) -> Optional[Receipt]:
    stmt = (
        select(Receipt)
        .options(selectinload(Receipt.line_items))
        .where(Receipt.id == receipt_id, Receipt.user_id == user_id)
    )
    return db.scalar(stmt)


def serialize_receipt_summary(receipt: Receipt) -> dict:
    return {
        'id': receipt.id,
        'savedCartId': receipt.saved_cart_id,
        'status': receipt.status,
        'imageUrl': receipt.image_path,
        'merchantName': receipt.merchant_name,
        'purchasedAt': receipt.purchased_at.isoformat() if receipt.purchased_at else None,
        'currency': receipt.currency,
        'subtotal': receipt.subtotal,
        'tax': receipt.tax,
        'totalAmount': receipt.total_amount,
        'totalDiscountAmount': receipt.total_discount_amount,
        'rawText': receipt.raw_text,
        'errorMessage': receipt.error_message,
        'createdAt': receipt.created_at.isoformat() if receipt.created_at else None,
        'updatedAt': receipt.updated_at.isoformat() if receipt.updated_at else None,
    }


def serialize_receipt_result(receipt: Receipt) -> dict:
    return {
        'receipt': serialize_receipt_summary(receipt),
        'lineItems': [
            {
                'id': item.id,
                'rawName': item.raw_name,
                'normalizedName': item.normalized_name,
                'quantity': item.quantity,
                'unitPrice': item.unit_price,
                'lineAmount': item.line_amount,
                'finalAmount': item.final_amount,
                'category': item.category,
                'confidence': item.confidence,
            }
            for item in receipt.line_items
        ],
    }
