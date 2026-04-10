import json
import shlex
import subprocess
from dataclasses import dataclass
from typing import Any, Dict, Optional

from ..core.settings import settings


class OpenClawScanRunnerError(Exception):
    def __init__(self, code: str, message: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = details or None


@dataclass
class OpenClawScanResult:
    name: str
    price: int
    sku: Optional[str]
    confidence: Optional[float]
    source: str
    raw_text: Optional[str]
    meta: Dict[str, Any]



def _optional_string(value: Any) -> Optional[str]:
    if isinstance(value, str):
        value = value.strip()
        if value:
            return value
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
    raise OpenClawScanRunnerError(
        code='OPENCLAW_RESULT_INVALID',
        message='OpenClaw confidence 값 형식이 올바르지 않아',
        details={'field': 'confidence'},
    )



def _parse_result_payload(payload: Dict[str, Any]) -> OpenClawScanResult:
    ok = payload.get('ok')
    if ok is False:
        error = payload.get('error') if isinstance(payload.get('error'), dict) else {}
        raise OpenClawScanRunnerError(
            code=_optional_string(error.get('code')) or 'OPENCLAW_SCAN_FAILED',
            message=_optional_string(error.get('message')) or 'OpenClaw scan runner가 분석에 실패했어',
            details=error.get('details') if isinstance(error.get('details'), dict) else None,
        )

    result = payload.get('result') if isinstance(payload.get('result'), dict) else payload

    name = _optional_string(result.get('name'))
    if not name:
        raise OpenClawScanRunnerError(
            code='OPENCLAW_RESULT_INVALID',
            message='OpenClaw 결과에 name 값이 없어',
            details={'field': 'name'},
        )

    price_value = result.get('price')
    if not isinstance(price_value, (int, float)):
        raise OpenClawScanRunnerError(
            code='OPENCLAW_RESULT_INVALID',
            message='OpenClaw 결과에 price 값이 없어',
            details={'field': 'price'},
        )

    price = int(price_value)
    if price <= 0:
        raise OpenClawScanRunnerError(
            code='OPENCLAW_RESULT_INVALID',
            message='OpenClaw 결과의 price 값이 올바르지 않아',
            details={'field': 'price', 'value': price_value},
        )

    meta = payload.get('meta') if isinstance(payload.get('meta'), dict) else {}
    return OpenClawScanResult(
        name=name,
        price=price,
        sku=_optional_string(result.get('sku')),
        confidence=_optional_confidence(result.get('confidence')),
        source=_optional_string(result.get('source')) or 'openclaw',
        raw_text=_optional_string(result.get('rawText')),
        meta=meta,
    )



def run_openclaw_scan(job_id: str, image_path: str) -> OpenClawScanResult:
    command_template = settings.openclaw_scan_command.strip()
    if not command_template:
        raise OpenClawScanRunnerError(
            code='OPENCLAW_COMMAND_NOT_CONFIGURED',
            message='OPENCLAW_SCAN_COMMAND 환경변수가 설정되지 않았어',
        )

    command = command_template.format(job_id=job_id, image_path=image_path)
    try:
        completed = subprocess.run(
            shlex.split(command),
            check=False,
            capture_output=True,
            text=True,
            timeout=max(settings.openclaw_scan_timeout_seconds, 1),
        )
    except subprocess.TimeoutExpired as exc:
        raise OpenClawScanRunnerError(
            code='OPENCLAW_TIMEOUT',
            message='OpenClaw scan runner 시간이 초과됐어',
            details={'timeoutSeconds': settings.openclaw_scan_timeout_seconds},
        ) from exc
    except Exception as exc:
        raise OpenClawScanRunnerError(
            code='OPENCLAW_COMMAND_EXEC_FAILED',
            message='OpenClaw scan runner 실행 자체에 실패했어',
            details={'exception': str(exc)},
        ) from exc

    stdout = (completed.stdout or '').strip()
    stderr = (completed.stderr or '').strip()

    if completed.returncode != 0:
        raise OpenClawScanRunnerError(
            code='OPENCLAW_COMMAND_FAILED',
            message='OpenClaw scan runner가 비정상 종료됐어',
            details={
                'returnCode': completed.returncode,
                'stderr': stderr or None,
                'stdout': stdout or None,
            },
        )

    if not stdout:
        raise OpenClawScanRunnerError(
            code='OPENCLAW_EMPTY_OUTPUT',
            message='OpenClaw scan runner 출력이 비어 있어',
            details={'stderr': stderr or None},
        )

    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise OpenClawScanRunnerError(
            code='OPENCLAW_INVALID_JSON',
            message='OpenClaw scan runner가 JSON이 아닌 출력을 반환했어',
            details={'stdout': stdout[:1000], 'stderr': stderr or None},
        ) from exc

    if not isinstance(payload, dict):
        raise OpenClawScanRunnerError(
            code='OPENCLAW_INVALID_JSON',
            message='OpenClaw scan runner 응답 최상위 형식이 올바르지 않아',
        )

    return _parse_result_payload(payload)
