#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from typing import Any, Dict, List, Optional


DEFAULT_TIMEOUT_SECONDS = 90
DEFAULT_SOURCE = 'openclaw-receipt-agent'
_ALLOWED_CATEGORIES = {'item', 'discount', 'coupon', 'subtotal', 'tax', 'payment'}


def _failure(code: str, message: str, details: Optional[Dict[str, Any]] = None) -> int:
    print(
        json.dumps(
            {
                'ok': False,
                'error': {
                    'code': code,
                    'message': message,
                    'details': details or None,
                },
            },
            ensure_ascii=False,
        )
    )
    return 0


def _success(result: Dict[str, Any], meta: Optional[Dict[str, Any]] = None) -> int:
    print(
        json.dumps(
            {
                'ok': True,
                'result': result,
                'meta': meta or {},
            },
            ensure_ascii=False,
        )
    )
    return 0


def _collect_strings(value: Any) -> List[str]:
    found: List[str] = []
    if isinstance(value, str):
        found.append(value)
    elif isinstance(value, dict):
        for nested in value.values():
            found.extend(_collect_strings(nested))
    elif isinstance(value, list):
        for nested in value:
            found.extend(_collect_strings(nested))
    return found


def _collect_objects(value: Any) -> List[Dict[str, Any]]:
    found: List[Dict[str, Any]] = []
    if isinstance(value, dict):
        found.append(value)
        for nested in value.values():
            found.extend(_collect_objects(nested))
    elif isinstance(value, list):
        for nested in value:
            found.extend(_collect_objects(nested))
    return found


def _extract_json_candidates(text: str) -> List[str]:
    text = text.strip()
    if not text:
        return []

    candidates: List[str] = []
    fence_matches = re.findall(r'```(?:json)?\s*(\{.*?\})\s*```', text, flags=re.S)
    candidates.extend(fence_matches)

    if text.startswith('{') and text.endswith('}'):
        candidates.append(text)

    brace_starts = [i for i, ch in enumerate(text) if ch == '{']
    for start in brace_starts:
        depth = 0
        for idx in range(start, len(text)):
            ch = text[idx]
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    candidates.append(text[start : idx + 1])
                    break

    deduped: List[str] = []
    seen = set()
    for item in candidates:
        normalized = item.strip()
        if normalized and normalized not in seen:
            seen.add(normalized)
            deduped.append(normalized)
    return deduped


def _coerce_result_shape(payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    candidate = payload.get('result') if isinstance(payload.get('result'), dict) else payload
    line_items = candidate.get('lineItems') if isinstance(candidate, dict) else None
    if isinstance(line_items, list) and line_items:
        return candidate
    if payload.get('ok') is False and isinstance(payload.get('error'), dict):
        return payload
    return None


def _search_payload_for_result(payload: Any) -> Optional[Dict[str, Any]]:
    for obj in _collect_objects(payload):
        shaped = _coerce_result_shape(obj)
        if shaped is not None:
            return shaped

    for text in _collect_strings(payload):
        for candidate in _extract_json_candidates(text):
            try:
                parsed = json.loads(candidate)
            except json.JSONDecodeError:
                continue
            shaped = _search_payload_for_result(parsed)
            if shaped is not None:
                return shaped

    return None


def _parse_agent_json(*chunks: str) -> Optional[Dict[str, Any]]:
    for chunk in chunks:
        text = (chunk or '').strip()
        if not text:
            continue

        try:
            payload = json.loads(text)
        except json.JSONDecodeError:
            payload = text

        shaped = _search_payload_for_result(payload)
        if shaped is not None:
            return shaped

        if isinstance(payload, str):
            for candidate in _extract_json_candidates(payload):
                try:
                    parsed = json.loads(candidate)
                except json.JSONDecodeError:
                    continue
                shaped = _search_payload_for_result(parsed)
                if shaped is not None:
                    return shaped

    combined = '\n'.join([(chunk or '').strip() for chunk in chunks if (chunk or '').strip()])
    if not combined:
        return None

    for candidate in _extract_json_candidates(combined):
        try:
            parsed = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        shaped = _search_payload_for_result(parsed)
        if shaped is not None:
            return shaped

    return None


def _optional_string(value: Any) -> Optional[str]:
    if isinstance(value, str):
        value = value.strip()
        if value:
            return value
    return None


def _optional_int(value: Any) -> Optional[int]:
    if value is None or isinstance(value, bool):
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


def _optional_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        value = float(value)
        if value < 0:
            return 0.0
        if value > 1:
            return 1.0
        return round(value, 4)
    return None


def _normalize_category(value: Any) -> str:
    category = (_optional_string(value) or 'item').lower()
    return category if category in _ALLOWED_CATEGORIES else 'item'


def _normalize_line_item(item: Any) -> Optional[Dict[str, Any]]:
    if not isinstance(item, dict):
        return None

    raw_name = _optional_string(item.get('rawName')) or _optional_string(item.get('name'))
    line_amount = _optional_int(item.get('lineAmount'))
    if not raw_name or line_amount is None:
        return None

    quantity = _optional_int(item.get('quantity'))
    if quantity is not None and quantity <= 0:
        quantity = 1

    return {
        'rawName': raw_name,
        'quantity': quantity,
        'unitPrice': _optional_int(item.get('unitPrice')),
        'lineAmount': line_amount,
        'finalAmount': _optional_int(item.get('finalAmount')),
        'category': _normalize_category(item.get('category')),
        'confidence': _optional_float(item.get('confidence')),
    }


def _normalize_result(result: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    raw_line_items = result.get('lineItems') if isinstance(result.get('lineItems'), list) else None
    if not raw_line_items:
        return None

    line_items = []
    for item in raw_line_items:
        normalized = _normalize_line_item(item)
        if normalized is not None:
            line_items.append(normalized)

    if not line_items:
        return None

    return {
        'merchantName': _optional_string(result.get('merchantName')),
        'purchasedAt': _optional_string(result.get('purchasedAt')),
        'currency': _optional_string(result.get('currency')) or 'KRW',
        'subtotal': _optional_int(result.get('subtotal')),
        'tax': _optional_int(result.get('tax')),
        'totalAmount': _optional_int(result.get('totalAmount')),
        'totalDiscountAmount': _optional_int(result.get('totalDiscountAmount')),
        'rawText': _optional_string(result.get('rawText')),
        'lineItems': line_items,
    }


def _build_prompt(receipt_id: str, image_path: str) -> str:
    return f'''You are analyzing a Korean grocery receipt image for the Cartly app.

Goal:
Extract a structured purchase summary from the receipt so it can be compared against a saved shopping cart.

Context:
- receiptId: {receipt_id}
- imagePath: {image_path}
- The image is on the local machine. Read the image file directly.
- Respond quickly. Avoid long explanations.
- Use the actual receipt text as much as possible.
- Do not invent placeholder item names.
- Prefer exact product names from the receipt, even if abbreviated.
- Ignore loyalty ids, approval numbers, card numbers, phone numbers, and store addresses unless they help determine merchant/date.
- `lineItems` should include actual purchased item rows plus clear discount/coupon/subtotal/tax/payment summary rows when visible.
- For purchased products use category `item`.
- For discounts or coupons use `discount` or `coupon`.
- For subtotal/tax/payment rows use `subtotal`, `tax`, or `payment`.
- quantity should be an integer when visible, otherwise 1 if the row clearly represents one purchased item.
- unitPrice should be the per-item price when inferable, otherwise null.
- lineAmount should be the printed row amount as an integer KRW amount without commas.
- finalAmount should be the final charged amount for that row if distinct, otherwise null.
- confidence must be between 0 and 1 when present.
- purchasedAt should be ISO-8601 if clearly visible, otherwise null.
- currency should be `KRW`.
- If no plausible purchased item rows can be extracted, return exactly this failure JSON instead:
{{
  "ok": false,
  "error": {{
    "code": "LOW_CONFIDENCE",
    "message": "영수증 상품/금액을 충분히 확정하지 못했어",
    "details": {{
      "reason": "unclear receipt"
    }}
  }}
}}

Otherwise return ONLY strict JSON. No markdown, no explanation, no code fence.
Use exactly this success schema:
{{
  "merchantName": "string or null",
  "purchasedAt": "ISO-8601 string or null",
  "currency": "KRW",
  "subtotal": 0,
  "tax": 0,
  "totalAmount": 0,
  "totalDiscountAmount": 0,
  "rawText": "string or null",
  "lineItems": [
    {{
      "rawName": "string",
      "quantity": 1,
      "unitPrice": 0,
      "lineAmount": 0,
      "finalAmount": 0,
      "category": "item",
      "confidence": 0.0
    }}
  ]
}}
'''


def main() -> int:
    parser = argparse.ArgumentParser(description='OpenClaw receipt runner for Cartly')
    parser.add_argument('--receipt-id', required=True)
    parser.add_argument('--image-path', required=True)
    args = parser.parse_args()

    agent_id = (
        os.environ.get('OPENCLAW_RECEIPT_ANALYSIS_AGENT_ID')
        or os.environ.get('OPENCLAW_RECEIPT_AGENT_ID')
        or os.environ.get('OPENCLAW_SCAN_AGENT_ID')
        or ''
    ).strip()
    if not agent_id:
        return _failure(
            'OPENCLAW_RECEIPT_AGENT_ID_NOT_CONFIGURED',
            'OPENCLAW_RECEIPT_ANALYSIS_AGENT_ID, OPENCLAW_RECEIPT_AGENT_ID, OPENCLAW_SCAN_AGENT_ID 중 하나가 필요해',
        )

    if not os.path.exists(args.image_path):
        return _failure(
            'IMAGE_NOT_FOUND',
            '분석할 영수증 이미지 파일을 찾지 못했어',
            {'imagePath': args.image_path},
        )

    timeout_seconds = int(
        os.environ.get(
            'OPENCLAW_RECEIPT_ANALYSIS_TIMEOUT_SECONDS',
            os.environ.get(
                'OPENCLAW_RECEIPT_TIMEOUT_SECONDS',
                os.environ.get('OPENCLAW_SCAN_TIMEOUT_SECONDS', str(DEFAULT_TIMEOUT_SECONDS)),
            ),
        )
        or DEFAULT_TIMEOUT_SECONDS
    )
    thinking = (
        os.environ.get('OPENCLAW_RECEIPT_ANALYSIS_THINKING')
        or os.environ.get('OPENCLAW_RECEIPT_THINKING')
        or os.environ.get('OPENCLAW_SCAN_THINKING')
        or 'medium'
    ).strip()
    prompt = _build_prompt(args.receipt_id, args.image_path)

    command = [
        'openclaw',
        'agent',
        '--agent',
        agent_id,
        '--message',
        prompt,
        '--local',
        '--timeout',
        str(timeout_seconds),
        '--thinking',
        thinking,
        '--json',
    ]

    try:
        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=max(timeout_seconds + 10, 20),
        )
    except subprocess.TimeoutExpired:
        return _failure(
            'OPENCLAW_RECEIPT_AGENT_TIMEOUT',
            'OpenClaw agent 응답 시간이 초과됐어',
            {'timeoutSeconds': timeout_seconds},
        )
    except Exception as exc:
        return _failure(
            'OPENCLAW_RECEIPT_AGENT_EXEC_FAILED',
            'OpenClaw agent 실행에 실패했어',
            {'exception': str(exc)},
        )

    stdout = (completed.stdout or '').strip()
    stderr = (completed.stderr or '').strip()

    if completed.returncode != 0:
        return _failure(
            'OPENCLAW_RECEIPT_AGENT_FAILED',
            'OpenClaw agent가 비정상 종료됐어',
            {
                'returnCode': completed.returncode,
                'stdout': stdout or None,
                'stderr': stderr or None,
            },
        )

    parsed = _parse_agent_json(stdout, stderr)
    if parsed is None:
        return _failure(
            'OPENCLAW_RECEIPT_AGENT_INVALID_OUTPUT',
            'OpenClaw agent 출력에서 영수증 결과 JSON을 추출하지 못했어',
            {
                'stdout': stdout[:4000] if stdout else None,
                'stderr': stderr[:4000] if stderr else None,
            },
        )

    if parsed.get('ok') is False:
        error = parsed.get('error') if isinstance(parsed.get('error'), dict) else {}
        return _failure(
            _optional_string(error.get('code')) or 'OPENCLAW_RECEIPT_AGENT_FAILED',
            _optional_string(error.get('message')) or 'OpenClaw agent가 영수증 분석에 실패했어',
            error.get('details') if isinstance(error.get('details'), dict) else None,
        )

    normalized = _normalize_result(parsed)
    if normalized is None:
        return _failure(
            'OPENCLAW_RECEIPT_AGENT_INVALID_OUTPUT',
            'OpenClaw agent 결과 형식이 영수증 스키마와 맞지 않아',
            {
                'parsed': parsed,
                'stdout': stdout[:4000] if stdout else None,
                'stderr': stderr[:4000] if stderr else None,
            },
        )

    return _success(
        {
            **normalized,
            'source': DEFAULT_SOURCE,
        },
        meta={
            'runner': 'openclaw',
            'workflow': 'receipt-compare-v1',
        },
    )


if __name__ == '__main__':
    sys.exit(main())
