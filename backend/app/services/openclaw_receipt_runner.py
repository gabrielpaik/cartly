import json
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Optional

from ..core.settings import settings


class OpenClawReceiptRunnerError(Exception):
    def __init__(self, code: str, message: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = details or None


@dataclass
class OpenClawReceiptLineItem:
    raw_name: str
    quantity: Optional[int]
    unit_price: Optional[int]
    line_amount: int
    final_amount: Optional[int]
    category: str
    confidence: Optional[float]


@dataclass
class OpenClawReceiptResult:
    merchant_name: Optional[str]
    purchased_at: Optional[str]
    currency: str
    subtotal: Optional[int]
    tax: Optional[int]
    total_amount: Optional[int]
    total_discount_amount: Optional[int]
    raw_text: Optional[str]
    line_items: list[OpenClawReceiptLineItem]
    meta: Dict[str, Any]


_ALLOWED_CATEGORIES = {'item', 'discount', 'coupon', 'subtotal', 'tax', 'payment'}


def _optional_string(value: Any) -> Optional[str]:
    if isinstance(value, str):
        value = value.strip()
        if value:
            return value
    return None


def _optional_int(value: Any) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return int(value)
    if isinstance(value, str):
        stripped = value.strip().replace(',', '')
        if not stripped:
            return None
        try:
            return int(float(stripped))
        except ValueError:
            return None
    return None


def _optional_confidence(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        confidence = float(value)
        if confidence < 0:
            return 0.0
        if confidence > 1:
            return 1.0
        return round(confidence, 4)
    raise OpenClawReceiptRunnerError(
        code='OPENCLAW_RECEIPT_RESULT_INVALID',
        message='OpenClaw 영수증 confidence 값 형식이 올바르지 않아',
        details={'field': 'confidence'},
    )


def _coerce_category(value: Any) -> str:
    category = _optional_string(value) or 'item'
    category = category.lower()
    if category not in _ALLOWED_CATEGORIES:
        return 'item'
    return category


def _parse_line_item(payload: Dict[str, Any]) -> OpenClawReceiptLineItem:
    raw_name = _optional_string(payload.get('rawName')) or _optional_string(payload.get('name'))
    if not raw_name:
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_RESULT_INVALID',
            message='OpenClaw 영수증 결과 line item에 rawName 값이 없어',
            details={'field': 'rawName'},
        )

    line_amount = _optional_int(payload.get('lineAmount'))
    if line_amount is None:
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_RESULT_INVALID',
            message='OpenClaw 영수증 결과 line item에 lineAmount 값이 없어',
            details={'field': 'lineAmount', 'rawName': raw_name},
        )

    quantity = _optional_int(payload.get('quantity'))
    if quantity is not None and quantity <= 0:
        quantity = 1

    return OpenClawReceiptLineItem(
        raw_name=raw_name,
        quantity=quantity,
        unit_price=_optional_int(payload.get('unitPrice')),
        line_amount=line_amount,
        final_amount=_optional_int(payload.get('finalAmount')),
        category=_coerce_category(payload.get('category')),
        confidence=_optional_confidence(payload.get('confidence')),
    )


def _parse_result_payload(payload: Dict[str, Any]) -> OpenClawReceiptResult:
    ok = payload.get('ok')
    if ok is False:
        error = payload.get('error') if isinstance(payload.get('error'), dict) else {}
        raise OpenClawReceiptRunnerError(
            code=_optional_string(error.get('code')) or 'OPENCLAW_RECEIPT_FAILED',
            message=_optional_string(error.get('message')) or 'OpenClaw 영수증 분석이 실패했어',
            details=error.get('details') if isinstance(error.get('details'), dict) else None,
        )

    result = payload.get('result') if isinstance(payload.get('result'), dict) else payload
    line_items_payload = result.get('lineItems') if isinstance(result.get('lineItems'), list) else None
    if not line_items_payload:
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_RESULT_INVALID',
            message='OpenClaw 영수증 결과에 lineItems 값이 없어',
            details={'field': 'lineItems'},
        )

    line_items = [_parse_line_item(item) for item in line_items_payload if isinstance(item, dict)]
    if not line_items:
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_RESULT_INVALID',
            message='OpenClaw 영수증 결과에서 유효한 line item을 찾지 못했어',
            details={'field': 'lineItems'},
        )

    meta = payload.get('meta') if isinstance(payload.get('meta'), dict) else {}
    return OpenClawReceiptResult(
        merchant_name=_optional_string(result.get('merchantName')),
        purchased_at=_optional_string(result.get('purchasedAt')),
        currency=_optional_string(result.get('currency')) or 'KRW',
        subtotal=_optional_int(result.get('subtotal')),
        tax=_optional_int(result.get('tax')),
        total_amount=_optional_int(result.get('totalAmount')),
        total_discount_amount=_optional_int(result.get('totalDiscountAmount')),
        raw_text=_optional_string(result.get('rawText')),
        line_items=line_items,
        meta=meta,
    )


def _default_command(receipt_id: str, image_path: str) -> str:
    repo_root = Path(__file__).resolve().parents[3]
    script_path = repo_root / 'scripts' / 'openclaw_receipt_runner.py'
    return f'{shlex.quote(sys.executable)} {shlex.quote(str(script_path))} --receipt-id {shlex.quote(receipt_id)} --image-path {shlex.quote(image_path)}'


def _receipt_command_template() -> str:
    for value in (
        settings.openclaw_receipt_analysis_command,
        settings.openclaw_receipt_command,
        settings.openclaw_receipt_scan_command,
    ):
        normalized = value.strip()
        if normalized:
            return normalized
    return ''


def _receipt_timeout_seconds() -> int:
    for value in (
        settings.openclaw_receipt_analysis_timeout_seconds,
        settings.openclaw_receipt_scan_timeout_seconds,
        settings.openclaw_receipt_timeout_seconds,
    ):
        if value and int(value) > 0:
            return int(value)
    return 120


def run_openclaw_receipt(receipt_id: str, image_path: str) -> OpenClawReceiptResult:
    command_template = _receipt_command_template()
    command = command_template.format(receipt_id=receipt_id, image_path=image_path) if command_template else _default_command(receipt_id, image_path)
    timeout_seconds = _receipt_timeout_seconds()

    try:
        completed = subprocess.run(
            shlex.split(command),
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
        )
    except subprocess.TimeoutExpired as exc:
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_TIMEOUT',
            message='OpenClaw 영수증 분석 시간이 초과됐어',
            details={'timeoutSeconds': timeout_seconds},
        ) from exc
    except Exception as exc:
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_COMMAND_EXEC_FAILED',
            message='OpenClaw 영수증 분석 runner 실행 자체에 실패했어',
            details={'exception': str(exc)},
        ) from exc

    stdout = (completed.stdout or '').strip()
    stderr = (completed.stderr or '').strip()

    if completed.returncode != 0:
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_COMMAND_FAILED',
            message='OpenClaw 영수증 분석 runner가 비정상 종료됐어',
            details={
                'returnCode': completed.returncode,
                'stderr': stderr or None,
                'stdout': stdout or None,
            },
        )

    if not stdout:
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_EMPTY_OUTPUT',
            message='OpenClaw 영수증 분석 runner 출력이 비어 있어',
            details={'stderr': stderr or None},
        )

    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_INVALID_JSON',
            message='OpenClaw 영수증 분석 runner가 JSON이 아닌 출력을 반환했어',
            details={'stdout': stdout[:2000], 'stderr': stderr or None},
        ) from exc

    if not isinstance(payload, dict):
        raise OpenClawReceiptRunnerError(
            code='OPENCLAW_RECEIPT_INVALID_JSON',
            message='OpenClaw 영수증 분석 응답 최상위 형식이 올바르지 않아',
        )

    return _parse_result_payload(payload)
