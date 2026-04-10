#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from typing import Any, Dict, List, Optional


DEFAULT_TIMEOUT_SECONDS = 90
DEFAULT_SOURCE = 'openclaw-agent'



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
    if isinstance(payload.get('result'), dict):
        nested = payload['result']
        if {'name', 'price'}.issubset(nested.keys()):
            return nested
    required_keys = {'name', 'price'}
    if required_keys.issubset(payload.keys()):
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



def _extract_sku(raw_text: Optional[str], sku: Optional[str]) -> Optional[str]:
    normalized = _optional_string(sku)
    if normalized and re.fullmatch(r'\d{6,7}', normalized):
        return normalized
    if not raw_text:
        return normalized
    match = re.search(r'\b(\d{6,7})\b', raw_text)
    if match:
        return match.group(1)
    return normalized



def _extract_brand_prefix(raw_text: Optional[str], name: str) -> Optional[str]:
    if not raw_text:
        return None
    idx = raw_text.find(name)
    if idx < 0:
        return None

    prefix = raw_text[:idx]
    prefix = re.sub(r'^\s*\d{6,7}\s+', '', prefix).strip()
    if not prefix:
        return None

    tokens = prefix.split()
    brand_rev: List[str] = []
    for token in reversed(tokens):
        cleaned = token.strip(' ,.:;()[]{}')
        if re.fullmatch(r"[A-Z][A-Z0-9&'/().-]*", cleaned):
            brand_rev.append(cleaned)
            continue
        break

    if not brand_rev:
        return None
    return ' '.join(reversed(brand_rev)).strip() or None



def _merge_brand_into_name(name: str, raw_text: Optional[str]) -> str:
    brand = _extract_brand_prefix(raw_text, name)
    if not brand:
        return name

    if name.upper().startswith(brand.upper()):
        return name
    return f'{brand} {name}'.strip()



def _normalize_result(result: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    name = _optional_string(result.get('name'))
    price = result.get('price')
    if not name or not isinstance(price, (int, float)):
        return None

    price = int(price)
    if price <= 0:
        return None

    raw_text = _optional_string(result.get('rawText'))
    sku = _extract_sku(raw_text, _optional_string(result.get('sku')))
    name = _merge_brand_into_name(name, raw_text)

    return {
        'name': name,
        'price': price,
        'sku': sku,
        'confidence': _optional_float(result.get('confidence')),
        'source': _optional_string(result.get('source')) or DEFAULT_SOURCE,
        'rawText': raw_text,
    }



def _build_prompt(job_id: str, image_path: str) -> str:
    return f'''You are analyzing a Korean grocery shelf label / price tag image for the Cartly app.

Goal:
Extract the most likely full product name and final selling price shown in the image as fast as possible.

Context:
- jobId: {job_id}
- imagePath: {image_path}
- The image is on the local machine. Read the image file directly.
- Respond quickly. Avoid long deliberation.
- Prioritize what a shopper should add to cart now.
- Prefer the full shelf-label name, including visible leading brand words (for example KIRKLAND SIGNATURE, THERABREATH, AKAI BOSHI) when they are part of the product display name.
- Include meaningful pack/size text only if it is clearly part of the product identity.
- Return the product name in Korean if visible, but keep visible brand words if they help identify the item.
- price must be an integer KRW amount without commas.
- If a clear 6-7 digit SKU/item code is visible, fill `sku` with that code.
- sku should be null only if unknown.
- confidence must be between 0 and 1.
- rawText should contain the most relevant visible OCR-like text snippet if available.
- source should be a short identifier like "openclaw-agent".
- Never guess with placeholders like "알 수 없음" or price `0`.
- If you cannot identify a plausible item and price, return exactly this failure JSON instead:
{{
  "ok": false,
  "error": {{
    "code": "LOW_CONFIDENCE",
    "message": "상품명/가격을 충분히 확정하지 못했어",
    "details": {{
      "reason": "unclear label"
    }}
  }}
}}

Otherwise return ONLY strict JSON. No markdown, no explanation, no code fence.
Use exactly this success schema:
{{
  "name": "string",
  "price": 0,
  "sku": null,
  "confidence": 0.0,
  "source": "openclaw-agent",
  "rawText": "string or null"
}}
'''



def main() -> int:
    parser = argparse.ArgumentParser(description='OpenClaw scan runner for Cartly')
    parser.add_argument('--job-id', required=True)
    parser.add_argument('--image-path', required=True)
    args = parser.parse_args()

    agent_id = (os.environ.get('OPENCLAW_SCAN_AGENT_ID') or '').strip()
    if not agent_id:
        return _failure(
            'OPENCLAW_AGENT_ID_NOT_CONFIGURED',
            'OPENCLAW_SCAN_AGENT_ID 환경변수가 설정되지 않았어',
        )

    if not os.path.exists(args.image_path):
        return _failure(
            'IMAGE_NOT_FOUND',
            '분석할 이미지 파일을 찾지 못했어',
            {'imagePath': args.image_path},
        )

    timeout_seconds = int(os.environ.get('OPENCLAW_SCAN_TIMEOUT_SECONDS', str(DEFAULT_TIMEOUT_SECONDS)) or DEFAULT_TIMEOUT_SECONDS)
    thinking = (os.environ.get('OPENCLAW_SCAN_THINKING') or 'medium').strip()
    prompt = _build_prompt(args.job_id, args.image_path)

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
            'OPENCLAW_AGENT_TIMEOUT',
            'OpenClaw agent 응답 시간이 초과됐어',
            {'timeoutSeconds': timeout_seconds},
        )
    except Exception as exc:
        return _failure(
            'OPENCLAW_AGENT_EXEC_FAILED',
            'OpenClaw agent 실행에 실패했어',
            {'exception': str(exc)},
        )

    stdout = (completed.stdout or '').strip()
    stderr = (completed.stderr or '').strip()

    if completed.returncode != 0:
        return _failure(
            'OPENCLAW_AGENT_FAILED',
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
            'OPENCLAW_AGENT_INVALID_OUTPUT',
            'OpenClaw agent 출력에서 결과 JSON을 추출하지 못했어',
            {
                'stdout': stdout[:4000] if stdout else None,
                'stderr': stderr[:4000] if stderr else None,
            },
        )

    normalized = _normalize_result(parsed)
    if normalized is None:
        return _failure(
            'OPENCLAW_AGENT_INVALID_RESULT',
            'OpenClaw agent 결과 형식이 요구사항과 맞지 않아',
            {'parsed': parsed},
        )

    meta = {
        'runner': 'openclaw-agent-cli',
        'agentId': agent_id,
        'thinking': thinking,
    }
    return _success(normalized, meta=meta)


if __name__ == '__main__':
    sys.exit(main())
