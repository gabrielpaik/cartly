from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import hmac
import html
import json
import re
from typing import Any, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from .explore_admin_service import get_explore_settings
from .explore_intent_normalizer import normalize_explore_intent

_COUPANG_API_DOMAIN = 'https://api-gateway.coupang.com'
_COUPANG_DEEPLINK_PATH = '/v2/providers/affiliate_open_api/apis/openapi/v1/deeplink'
_COUPANG_HMAC_ALGORITHM = 'HmacSHA256'
_NAVER_SHOPPING_API_URL = 'https://openapi.naver.com/v1/search/shop.json'
_HTML_TAG_RE = re.compile(r'<[^>]+>')
_PACK_COUNT_RE = re.compile(r'(\d+)\s*(개|입|팩|pack|봉|병|캔|세트)')
_MULTIPACK_X_RE = re.compile(r'(?:x|×)\s*(\d+)')
_SIZE_OR_COUNT_TOKEN_RE = re.compile(r'^\d+(?:\.\d+)?(?:ml|l|g|kg|개|입|팩|봉|병|캔|매|세트)?$')
_QUERY_TITLE_NEGATIVE_RULES: list[tuple[str, set[str]]] = [
    ('우유', {'분유', '탈지분유', '전지분유', '두유', '연유', '요거트', '요구르트'}),
    ('생수', {'탄산수', '두유', '주스'}),
    ('물', {'탄산수', '주스'}),
    ('계란', {'메추리알'}),
    ('휴지', {'키친타월', '물티슈'}),
]
_GENERIC_BLOCKED_TITLE_HINTS = {'도매', '업소용', '10판이상주문'}


def _normalize_source_type(value: str) -> str:
    normalized = (value or '').strip()
    if normalized in {'currentCart', 'pendingReview', 'repeatPurchase'}:
        return normalized
    return 'pendingReview'


def _affiliate_keys_ready(*, enabled: bool, access_key: str, secret_key: str) -> bool:
    return bool(enabled and access_key.strip() and secret_key.strip())


def _naver_keys_ready(*, enabled: bool, client_id: str, client_secret: str) -> bool:
    return bool(enabled and client_id.strip() and client_secret.strip())


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


def _clean_html_text(value: Any) -> str:
    text = html.unescape(str(value or ''))
    text = _HTML_TAG_RE.sub(' ', text)
    return re.sub(r'\s+', ' ', text).strip()


def _parse_int(value: Any) -> Optional[int]:
    digits = re.sub(r'[^0-9]', '', str(value or ''))
    if not digits:
        return None
    try:
        return int(digits)
    except ValueError:
        return None


def _format_price_delta(reference_price: int, candidate_price: int) -> str:
    delta = candidate_price - reference_price
    if delta == 0:
        return '기준 가격과 같아요'
    direction = '비싸요' if delta > 0 else '저렴해요'
    return f'기준가 대비 {abs(delta):,}원 {direction}'


def _extract_pack_count(text: str) -> Optional[int]:
    normalized_text = (text or '').lower()

    x_match = _MULTIPACK_X_RE.search(normalized_text)
    if x_match:
        try:
            value = int(x_match.group(1))
        except ValueError:
            value = 0
        if value > 0:
            return value

    match = _PACK_COUNT_RE.search(normalized_text)
    if not match:
        return None
    try:
        value = int(match.group(1))
    except ValueError:
        return None
    if value <= 0:
        return None
    return value


def _contains_any(text: str, words: set[str]) -> bool:
    return any(word in text for word in words)


def _matches_negative_family_rule(query_text: str, title_text: str) -> bool:
    normalized_query = (query_text or '').lower()
    normalized_title = (title_text or '').lower()
    for query_hint, blocked_words in _QUERY_TITLE_NEGATIVE_RULES:
        if query_hint in normalized_query and _contains_any(normalized_title, blocked_words):
            return True
    return False


def _is_price_outlier(reference_price: Optional[int], candidate_price: Optional[int], *, allow_multipack: bool) -> bool:
    if reference_price is None or candidate_price is None or reference_price <= 0 or allow_multipack:
        return False
    ratio = candidate_price / reference_price
    return ratio > 2.2 or ratio < 0.35


def _score_naver_item(
    *,
    query_text: str,
    query_tokens: list[str],
    title_text: str,
    item: dict[str, Any],
    reference_price: Optional[int],
) -> int:
    title_lower = title_text.lower()
    score = 0

    normalized_query_text = (query_text or '').strip().lower()
    if normalized_query_text and normalized_query_text in title_lower:
        score += 24

    for token in query_tokens:
        token = (token or '').strip().lower()
        if token and token in title_lower:
            score += 10

    pack_count = _extract_pack_count(title_text)
    if pack_count is None or pack_count <= 1:
        score += 8
    elif pack_count == 2:
        score += 1
    else:
        score -= min((pack_count - 1) * 2, 14)

    candidate_price = _parse_int(item.get('lprice'))
    if reference_price is not None and candidate_price is not None and reference_price > 0:
        ratio = candidate_price / reference_price
        if 0.7 <= ratio <= 1.35:
            score += 16
        elif 0.5 <= ratio <= 1.7:
            score += 8
        elif ratio > 2.2 or ratio < 0.35:
            score -= 20

    mall_name = _clean_html_text(item.get('mallName'))
    if mall_name:
        score += 2

    return score


def _is_candidate_naver_item_acceptable(
    *,
    query_text: str,
    query_tokens: list[str],
    title_text: str,
    item: dict[str, Any],
    reference_price: Optional[int],
) -> bool:
    if not title_text.strip():
        return False

    if _matches_negative_family_rule(query_text, title_text):
        return False

    title_lower = title_text.lower()
    if any(hint in title_lower for hint in _GENERIC_BLOCKED_TITLE_HINTS):
        return False

    query_pack_count = _extract_pack_count(query_text)
    title_pack_count = _extract_pack_count(title_text)
    allow_multipack = bool(query_pack_count and query_pack_count > 1)

    if not allow_multipack and title_pack_count is not None and title_pack_count > 2:
        return False

    candidate_price = _parse_int(item.get('lprice'))
    if _is_price_outlier(reference_price, candidate_price, allow_multipack=allow_multipack):
        return False

    title_lower = title_text.lower()
    matched_token_count = sum(1 for token in query_tokens if token and token.lower() in title_lower)
    if query_tokens and matched_token_count == 0:
        return False

    return True


def _is_cheaper_than_reference(reference_price: Optional[int], candidate_price: Optional[int]) -> bool:
    if reference_price is None or candidate_price is None or reference_price <= 0:
        return False
    return candidate_price < int(reference_price * 0.95)


def _is_strong_same_product_candidate(
    *,
    query_text: str,
    query_tokens: list[str],
    title_text: str,
) -> bool:
    normalized_query = (query_text or '').strip().lower()
    normalized_title = (title_text or '').strip().lower()
    if not normalized_query or not normalized_title:
        return False

    query_pack_count = _extract_pack_count(normalized_query)
    title_pack_count = _extract_pack_count(normalized_title)
    if query_pack_count is not None and title_pack_count is not None and query_pack_count != title_pack_count:
        return False

    if normalized_query in normalized_title:
        return True

    return False


def _is_size_or_count_token(token: str) -> bool:
    return bool(_SIZE_OR_COUNT_TOKEN_RE.match((token or '').strip().lower()))


def _meaningful_query_tokens(query_tokens: list[str]) -> list[str]:
    meaningful = [token for token in query_tokens if token and not _is_size_or_count_token(token)]
    return meaningful or [token for token in query_tokens if token]


def _match_query_token_count(*, query_tokens: list[str], title_text: str) -> int:
    title_tokens = set(normalize_explore_intent(title_text).intent_tokens)
    return sum(1 for token in query_tokens if token and token in title_tokens)


def _parse_admin_datetime(value: Any) -> Optional[datetime]:
    text = str(value or '').strip()
    if not text:
        return None
    try:
        parsed = datetime.fromisoformat(text.replace('Z', '+00:00'))
    except ValueError:
        return None
    if parsed.tzinfo is not None:
        return parsed.astimezone(timezone.utc).replace(tzinfo=None)
    return parsed


def _is_editorial_item_active(item: dict[str, Any], *, now: Optional[datetime] = None) -> bool:
    deleted_at = _parse_admin_datetime(item.get('deletedAt'))
    if deleted_at is not None:
        return False

    current = now or datetime.utcnow()
    starts_at = _parse_admin_datetime(item.get('startsAt'))
    ends_at = _parse_admin_datetime(item.get('endsAt'))
    if starts_at is not None and starts_at > current:
        return False
    if ends_at is not None and ends_at < current:
        return False
    return True


def _is_candidate_editorial_item_acceptable(
    *,
    query_text: str,
    query_tokens: list[str],
    title_text: str,
    reference_price: Optional[int],
    candidate_price: Optional[int],
) -> bool:
    _ = reference_price, candidate_price
    if not title_text.strip():
        return False

    if _matches_negative_family_rule(query_text, title_text):
        return False

    title_lower = title_text.lower()
    if any(hint in title_lower for hint in _GENERIC_BLOCKED_TITLE_HINTS):
        return False

    meaningful_tokens = _meaningful_query_tokens(query_tokens)
    matched_token_count = _match_query_token_count(
        query_tokens=meaningful_tokens,
        title_text=title_text,
    )
    if meaningful_tokens and matched_token_count > 0:
        return True

    normalized_query = (query_text or '').strip().lower()
    return bool(normalized_query and normalized_query in title_lower)


def _score_editorial_item(
    *,
    query_text: str,
    query_tokens: list[str],
    title_text: str,
    reference_price: Optional[int],
    candidate_price: Optional[int],
    display_slot: Optional[int],
) -> int:
    score = 0
    matched_token_count = _match_query_token_count(
        query_tokens=_meaningful_query_tokens(query_tokens),
        title_text=title_text,
    )
    score += min(matched_token_count * 40, 240)

    if _is_strong_same_product_candidate(
        query_text=query_text,
        query_tokens=query_tokens,
        title_text=title_text,
    ):
        score += 220

    if _is_cheaper_than_reference(reference_price, candidate_price):
        score += 40

    if display_slot is not None and display_slot > 0:
        score += max(0, 20 - min(display_slot, 20))

    return score


def _build_editorial_highlights(
    item: dict[str, Any],
    *,
    reference_price: Optional[int],
) -> list[str]:
    highlights: list[str] = []

    candidate_price = _parse_int(item.get('price'))
    if reference_price is not None and candidate_price is not None:
        highlights.append(_format_price_delta(reference_price, candidate_price))

    return highlights[:4]


def _load_editorial_candidate_offers(
    *,
    db: Optional[OrmSession],
    query_text: str,
    query_tokens: list[str],
    reference_price: Optional[int],
) -> list[dict[str, Any]]:
    if db is None:
        return []

    try:
        explore_settings = get_explore_settings(db)
    except Exception:
        return []

    if not bool(explore_settings.get('editorialRecommendationsEnabled', True)):
        return []

    raw_items = explore_settings.get('editorialRecommendationsItems')
    if not isinstance(raw_items, list):
        return []

    offers: list[dict[str, Any]] = []
    current = datetime.utcnow()
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        if not _is_editorial_item_active(item, now=current):
            continue

        title = _clean_html_text(item.get('title'))
        deeplink = str(item.get('deeplinkUrl') or item.get('url') or '').strip()
        if not title or not deeplink:
            continue

        candidate_price = _parse_int(item.get('price'))
        if not _is_candidate_editorial_item_acceptable(
            query_text=query_text,
            query_tokens=query_tokens,
            title_text=title,
            reference_price=reference_price,
            candidate_price=candidate_price,
        ):
            continue

        raw_display_slot = item.get('displaySlot')
        display_slot = raw_display_slot if isinstance(raw_display_slot, int) else _parse_int(raw_display_slot)
        provider = str(item.get('provider') or '').strip() or '추천'
        offers.append(
            {
                'provider': provider,
                'title': title,
                'subtitle': provider,
                'price': candidate_price,
                'thumbnailUrl': str(item.get('thumbnailUrl') or '').strip() or None,
                'deeplinkUrl': deeplink,
                '_score': _score_editorial_item(
                    query_text=query_text,
                    query_tokens=query_tokens,
                    title_text=title,
                    reference_price=reference_price,
                    candidate_price=candidate_price,
                    display_slot=display_slot,
                ),
                'highlights': _build_editorial_highlights(
                    item,
                    reference_price=reference_price,
                ),
                '_sourceType': 'admin_curated',
                '_isAdminCurated': True,
            }
        )

    return offers


def _build_naver_highlights(item: dict[str, Any], *, reference_price: Optional[int]) -> list[str]:
    highlights: list[str] = []

    mall_name = _clean_html_text(item.get('mallName'))
    brand = _clean_html_text(item.get('brand'))
    maker = _clean_html_text(item.get('maker'))
    lprice = _parse_int(item.get('lprice'))
    hprice = _parse_int(item.get('hprice'))

    if mall_name:
        highlights.append(f'판매처: {mall_name}')
    seller_bits = [value for value in (brand, maker) if value]
    if seller_bits:
        highlights.append('브랜드/제조사: ' + ' · '.join(dict.fromkeys(seller_bits)))
    if reference_price is not None and lprice is not None:
        highlights.append(_format_price_delta(reference_price, lprice))
    elif lprice is not None and hprice is not None and hprice > lprice:
        highlights.append(f'네이버 최저가 {lprice:,}원, 최고가 {hprice:,}원')

    categories = [
        _clean_html_text(item.get(key))
        for key in ('category1', 'category2', 'category3', 'category4')
    ]
    categories = [value for value in categories if value]
    if categories:
        highlights.append('카테고리: ' + ' > '.join(categories[:3]))

    return highlights[:4]


def search_naver_shopping_offers(
    *,
    intent_key: str,
    query_text: str,
    source_type: str,
    reference_price: Optional[int],
    db: Optional[OrmSession] = None,
    enabled: Optional[bool] = None,
    client_id: Optional[str] = None,
    client_secret: Optional[str] = None,
) -> dict[str, Any]:
    normalized = normalize_explore_intent(query_text)
    normalized_source_type = _normalize_source_type(source_type)
    effective_intent_key = (intent_key or '').strip() or normalized.intent_key
    effective_enabled = settings.naver_shopping_search_enabled if enabled is None else enabled
    effective_client_id = settings.naver_shopping_client_id if client_id is None else client_id
    effective_client_secret = settings.naver_shopping_client_secret if client_secret is None else client_secret
    search_ready = _naver_keys_ready(
        enabled=effective_enabled,
        client_id=effective_client_id,
        client_secret=effective_client_secret,
    )

    offers: list[dict[str, Any]] = _load_editorial_candidate_offers(
        db=db,
        query_text=normalized.normalized_query_text,
        query_tokens=normalized.intent_tokens,
        reference_price=reference_price,
    )
    error_code: Optional[str] = None

    if search_ready:
        request_url = _NAVER_SHOPPING_API_URL + '?' + urlencode(
            {
                'query': normalized.normalized_query_text,
                'display': 8,
                'sort': 'sim',
            }
        )
        request = Request(
            url=request_url,
            headers={
                'X-Naver-Client-Id': effective_client_id.strip(),
                'X-Naver-Client-Secret': effective_client_secret.strip(),
                'Accept': 'application/json',
            },
        )
        try:
            with urlopen(request, timeout=5) as response:
                payload = json.loads(response.read().decode('utf-8'))
            items = payload.get('items') if isinstance(payload, dict) else None
            if isinstance(items, list):
                for item in items:
                    if not isinstance(item, dict):
                        continue
                    title = _clean_html_text(item.get('title'))
                    link = str(item.get('link') or '').strip()
                    if not title or not link:
                        continue
                    if not _is_candidate_naver_item_acceptable(
                        query_text=normalized.normalized_query_text,
                        query_tokens=normalized.intent_tokens,
                        title_text=title,
                        item=item,
                        reference_price=reference_price,
                    ):
                        continue
                    mall_name = _clean_html_text(item.get('mallName')) or '네이버쇼핑'
                    offers.append(
                        {
                            'provider': mall_name,
                            'title': title,
                            'subtitle': mall_name,
                            'price': _parse_int(item.get('lprice')),
                            'thumbnailUrl': str(item.get('image') or '').strip() or None,
                            'deeplinkUrl': link,
                            '_score': _score_naver_item(
                                query_text=normalized.normalized_query_text,
                                query_tokens=normalized.intent_tokens,
                                title_text=title,
                                item=item,
                                reference_price=reference_price,
                            ),
                            'highlights': _build_naver_highlights(
                                item,
                                reference_price=reference_price,
                            ),
                            '_sourceType': 'search',
                        }
                    )
        except HTTPError as exc:
            error_code = f'http_{exc.code}'
        except (URLError, TimeoutError, json.JSONDecodeError):
            error_code = 'fetch_failed'
    else:
        error_code = 'naver_not_configured'

    editorial_offers = [
        offer for offer in offers if str(offer.get('_sourceType') or '') == 'admin_curated'
    ]
    search_offers = [
        offer for offer in offers if str(offer.get('_sourceType') or '') == 'search'
    ]

    editorial_offers.sort(
        key=lambda offer: (
            -int(offer.get('_score') or 0),
            int(offer.get('price') or 10**12),
            str(offer.get('title') or ''),
        )
    )
    search_offers.sort(
        key=lambda offer: (
            int(offer.get('_score') or 0),
            -int(offer.get('price') or 0) if offer.get('price') else 0,
        ),
        reverse=True,
    )

    combined_candidates = [
        *editorial_offers[:3],
        *search_offers[:3],
    ]

    deduped_offers: list[dict[str, Any]] = []
    seen_urls: set[str] = set()
    admin_curated_candidate_found = False
    for offer in combined_candidates:
        deeplink = str(offer.get('deeplinkUrl') or '').strip()
        if not deeplink or deeplink in seen_urls:
            continue
        seen_urls.add(deeplink)
        admin_curated_candidate_found = (
            admin_curated_candidate_found or bool(offer.pop('_isAdminCurated', False))
        )
        offer.pop('_score', None)
        offer.pop('_sourceType', None)
        deduped_offers.append(offer)

    exact_cheaper_offers = [
        offer
        for offer in deduped_offers
        if _is_strong_same_product_candidate(
            query_text=normalized.normalized_query_text,
            query_tokens=normalized.intent_tokens,
            title_text=str(offer.get('title') or ''),
        )
        and _is_cheaper_than_reference(reference_price, _parse_int(offer.get('price')))
    ]

    presentation_mode = 'show_offers' if deduped_offers else 'none'
    generic_message = None
    visible_offers: list[dict[str, Any]] = deduped_offers

    return {
        'version': 1,
        'enabled': effective_enabled,
        'provider': 'naver-shopping',
        'query': {
            'intentKey': effective_intent_key,
            'rawQueryText': query_text,
            'normalizedQueryText': normalized.normalized_query_text,
            'intentTokens': normalized.intent_tokens,
            'sourceType': normalized_source_type,
            'referencePrice': reference_price,
        },
        'bridge': {
            'mode': 'naver_shopping_search',
            'searchReady': search_ready,
            'fallbackProvider': 'coupang-partners',
            'errorCode': error_code,
        },
        'presentation': {
            'mode': presentation_mode,
            'genericMessage': generic_message,
            'linkWrappingReady': False,
            'exactCheaperCandidateFound': bool(exact_cheaper_offers),
            'adminCuratedCandidateFound': admin_curated_candidate_found,
        },
        'offers': visible_offers,
    }


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
