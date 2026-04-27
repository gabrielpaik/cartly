from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import hmac
import json
from typing import Any, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from ..core.settings import settings
from .explore_intent_normalizer import normalize_explore_intent

_COUPANG_API_DOMAIN = 'https://api-gateway.coupang.com'
_COUPANG_DEEPLINK_PATH = '/v2/providers/affiliate_open_api/apis/openapi/v1/deeplink'
_COUPANG_HMAC_ALGORITHM = 'HmacSHA256'


def _normalize_source_type(value: str) -> str:
    normalized = (value or '').strip()
    if normalized in {'currentCart', 'pendingReview', 'repeatPurchase'}:
        return normalized
    return 'pendingReview'


def _affiliate_keys_ready(*, enabled: bool, access_key: str, secret_key: str) -> bool:
    return bool(enabled and access_key.strip() and secret_key.strip())


def _signed_datetime() -> str:
    return datetime.now(timezone.utc).strftime("%y%m%dT%H%M%SZ")


def _build_coupang_authorization(*, method: str, path: str, access_key: str, secret_key: str, query: str = '') -> str:
    signed_date = _signed_datetime()
    message = f'{signed_date}{method.upper()}{path}{query}'
    signature = hmac.new(
        secret_key.encode('utf-8'),
        message.encode('utf-8'),
        hashlib.sha256,
    ).hexdigest()
    return (
        f'CEA algorithm={_COUPANG_HMAC_ALGORITHM}, '
        f'access-key={access_key.strip()}, '
        f'signed-date={signed_date}, '
        f'signature={signature}'
    )


def _bridge_path(
    *,
    intent_key: str,
    query_text: str,
    source_type: str,
    reference_price: Optional[int],
) -> str:
    params = {
        'intentKey': (intent_key or '').strip(),
        'q': normalize_explore_intent(query_text).normalized_query_text,
        'sourceType': _normalize_source_type(source_type),
    }
    if reference_price is not None:
        params['referencePrice'] = str(reference_price)
    return '/v1/explore/offers/coupang-partners/deeplink?' + urlencode(params)


def build_coupang_search_url(query_text: str) -> str:
    normalized = normalize_explore_intent(query_text).normalized_query_text
    return 'https://www.coupang.com/np/search?' + urlencode(
        {
            'component': '',
            'q': normalized,
            'channel': 'user',
        }
    )


def _extract_affiliate_url(payload: dict[str, Any]) -> Optional[str]:
    data = payload.get('data')
    if not isinstance(data, list) or not data:
        return None
    first = data[0]
    if not isinstance(first, dict):
        return None

    for key in ('shortenUrl', 'shortenedUrl', 'landingUrl', 'deeplink', 'url'):
        value = first.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def issue_coupang_affiliate_url(target_url: str, *, enabled: bool, access_key: str, secret_key: str) -> Optional[str]:
    if not _affiliate_keys_ready(enabled=enabled, access_key=access_key, secret_key=secret_key):
        return None

    body = json.dumps({'coupangUrls': [target_url]}).encode('utf-8')
    authorization = _build_coupang_authorization(
        method='POST',
        path=_COUPANG_DEEPLINK_PATH,
        access_key=access_key,
        secret_key=secret_key,
    )
    request = Request(
        url=f'{_COUPANG_API_DOMAIN}{_COUPANG_DEEPLINK_PATH}',
        method='POST',
        data=body,
        headers={
            'Authorization': authorization,
            'Content-Type': 'application/json;charset=UTF-8',
            'Accept': 'application/json',
        },
    )

    try:
        with urlopen(request, timeout=5) as response:
            payload = json.loads(response.read().decode('utf-8'))
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError):
        return None

    if not isinstance(payload, dict):
        return None

    r_code = str(payload.get('rCode') or '').strip()
    if r_code not in {'', '0'}:
        return None

    return _extract_affiliate_url(payload)


def build_coupang_offer_preview(
    *,
    intent_key: str,
    query_text: str,
    source_type: str,
    reference_price: Optional[int],
    enabled: Optional[bool] = None,
    access_key: Optional[str] = None,
    secret_key: Optional[str] = None,
) -> dict[str, Any]:
    normalized = normalize_explore_intent(query_text)
    normalized_source_type = _normalize_source_type(source_type)
    effective_intent_key = (intent_key or '').strip() or normalized.intent_key
    effective_enabled = settings.coupang_partners_enabled if enabled is None else enabled
    effective_access_key = settings.coupang_partners_access_key if access_key is None else access_key
    effective_secret_key = settings.coupang_partners_secret_key if secret_key is None else secret_key
    affiliate_ready = _affiliate_keys_ready(
        enabled=effective_enabled,
        access_key=effective_access_key,
        secret_key=effective_secret_key,
    )
    fallback_search_url = build_coupang_search_url(normalized.normalized_query_text)
    bridge_path = _bridge_path(
        intent_key=effective_intent_key,
        query_text=normalized.normalized_query_text,
        source_type=normalized_source_type,
        reference_price=reference_price,
    )

    return {
        'version': 1,
        'enabled': effective_enabled,
        'provider': 'coupang-partners',
        'query': {
            'intentKey': effective_intent_key,
            'rawQueryText': query_text,
            'normalizedQueryText': normalized.normalized_query_text,
            'intentTokens': normalized.intent_tokens,
            'sourceType': normalized_source_type,
            'referencePrice': reference_price,
        },
        'bridge': {
            'mode': 'affiliate_api' if affiliate_ready else 'search_fallback',
            'affiliateReady': affiliate_ready,
            'deeplinkPath': bridge_path,
            'fallbackSearchUrl': fallback_search_url,
        },
        'offers': [
            {
                'provider': 'coupang-partners',
                'title': f'{normalized.normalized_query_text} same-intent 오퍼 준비 중',
                'subtitle': '실제 파트너 딥링크 발급은 redirect 시점에 서버에서 처리하고, 실패하면 검색 결과로 안전하게 내려가요.' if affiliate_ready else '파트너 키가 아직 없어서 지금은 검색 fallback 모드예요. 키가 들어오면 같은 endpoint로 실제 제휴 링크를 발급해요.',
                'price': reference_price,
                'deeplinkUrl': bridge_path,
                'highlights': [
                    f'소스: {normalized_source_type}',
                    f'정규화 쿼리: {normalized.normalized_query_text}',
                    'redirect 시 서버에서 affiliate deeplink 발급 시도',
                    '실패 시 일반 Coupang 검색으로 fallback',
                ],
            },
            {
                'provider': 'coupang-search-preview',
                'title': '쿠팡 검색 프리뷰',
                'subtitle': normalized.normalized_query_text,
                'price': None,
                'deeplinkUrl': fallback_search_url,
                'highlights': [
                    '비제휴 검색 URL',
                    'same-intent 검색어 검증용',
                ],
            },
        ],
    }


def resolve_coupang_redirect(
    *,
    intent_key: str,
    query_text: str,
    source_type: str,
    reference_price: Optional[int],
    enabled: Optional[bool] = None,
    access_key: Optional[str] = None,
    secret_key: Optional[str] = None,
) -> str:
    _ = intent_key, source_type, reference_price
    fallback_search_url = build_coupang_search_url(query_text)
    affiliate_url = issue_coupang_affiliate_url(
        fallback_search_url,
        enabled=settings.coupang_partners_enabled if enabled is None else enabled,
        access_key=settings.coupang_partners_access_key if access_key is None else access_key,
        secret_key=settings.coupang_partners_secret_key if secret_key is None else secret_key,
    )
    return affiliate_url or fallback_search_url
