import json
import re
from copy import deepcopy
from datetime import datetime, timedelta
from html import unescape
from html.parser import HTMLParser
from typing import Any, Dict, Iterable, List, Optional
from urllib.parse import parse_qs, urljoin, urlparse
from urllib.request import Request, urlopen
from uuid import uuid4

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppEvent, AppSetting

EXPLORE_SETTINGS_KEY = 'explore_admin_settings'
EXPLORE_SECTION_IDS = (
    'heroSummary',
    'decisionInbox',
    'revisitItems',
    'repeatCandidates',
    'editorialPicks',
    'offerSlots',
    'savedContext',
    'storeContextPromo',
)

EXPLORE_STATE_IDS = (
    'activeShopping',
    'postSave',
    'idlePlanning',
    'storeContext',
)

DEFAULT_STATE_ORDERS: Dict[str, str] = {
    'activeShoppingSectionOrder': 'offerSlots,heroSummary,decisionInbox,revisitItems',
    'postSaveSectionOrder': 'savedContext,decisionInbox,repeatCandidates,editorialPicks,offerSlots',
    'idlePlanningSectionOrder': 'savedContext,repeatCandidates,editorialPicks,offerSlots',
    'storeContextSectionOrder': 'storeContextPromo,savedContext,editorialPicks,repeatCandidates,offerSlots',
}

STATE_RULE_SPECS: Dict[str, tuple[int, int, int]] = {
    'revisitRecentScanLimit': (3, 0, 8),
    'revisitCartItemLimit': (3, 0, 8),
    'revisitMaxItems': (4, 0, 12),
    'repeatMinCount': (2, 1, 10),
    'repeatMaxItems': (4, 0, 12),
    'offerMaxSlots': (3, 0, 12),
    'storeContextMaxPromos': (3, 0, 12),
}

DEFAULT_STATE_RULES: Dict[str, Dict[str, int]] = {
    'activeShopping': {
        'revisitRecentScanLimit': 3,
        'revisitCartItemLimit': 3,
        'revisitMaxItems': 4,
        'repeatMinCount': 2,
        'repeatMaxItems': 2,
        'offerMaxSlots': 3,
        'storeContextMaxPromos': 0,
    },
    'postSave': {
        'revisitRecentScanLimit': 2,
        'revisitCartItemLimit': 2,
        'revisitMaxItems': 3,
        'repeatMinCount': 2,
        'repeatMaxItems': 4,
        'offerMaxSlots': 3,
        'storeContextMaxPromos': 1,
    },
    'idlePlanning': {
        'revisitRecentScanLimit': 0,
        'revisitCartItemLimit': 0,
        'revisitMaxItems': 0,
        'repeatMinCount': 2,
        'repeatMaxItems': 4,
        'offerMaxSlots': 2,
        'storeContextMaxPromos': 0,
    },
    'storeContext': {
        'revisitRecentScanLimit': 0,
        'revisitCartItemLimit': 0,
        'revisitMaxItems': 0,
        'repeatMinCount': 2,
        'repeatMaxItems': 3,
        'offerMaxSlots': 2,
        'storeContextMaxPromos': 3,
    },
}

DEFAULT_STATE_PROMO_POLICIES: Dict[str, Dict[str, Any]] = {
    'activeShopping': {
        'allowSponsoredPromos': False,
        'maxSponsoredPromos': 0,
        'organicFirst': True,
    },
    'postSave': {
        'allowSponsoredPromos': True,
        'maxSponsoredPromos': 1,
        'organicFirst': True,
    },
    'idlePlanning': {
        'allowSponsoredPromos': True,
        'maxSponsoredPromos': 1,
        'organicFirst': True,
    },
    'storeContext': {
        'allowSponsoredPromos': True,
        'maxSponsoredPromos': 2,
        'organicFirst': False,
    },
}

DEFAULT_DECISION_COPY: Dict[str, str] = {
    'recentScanPendingReasonLabel': '아직 담기 전이에요',
    'recentScanPendingBody': '방금 스캔했지만 아직 카트에 담지 않았어요. 지금 확인해 두시면 놓치지 않아요.',
    'recentScanInCartReasonLabel': '담은 뒤 한 번 더 보기',
    'recentScanInCartBody': '이미 카트에 담았어요. 결제 전에 다른 선택지가 있는지만 가볍게 확인해보세요.',
    'currentCartHighImpactReasonLabel': '합계 영향이 커요',
    'currentCartHighImpactBody': '수량이나 가격 영향이 큰 상품이에요. 비슷한 대안과 비교하면 체감 차이가 날 수 있어요.',
    'currentCartDefaultReasonLabel': '결제 전에 확인해보세요',
    'currentCartDefaultBody': '지금 카트에 담아둔 상품이에요. 결제 전에 한 번만 더 비교해보세요.',
    'offerReasonLabelActiveShopping': '지금 비교해보세요',
    'offerReasonLabelPostSave': '저장한 뒤 다시 보기',
    'offerReasonLabelIdlePlanning': '다음 장보기 준비',
    'offerReasonLabelStoreContext': '지금 매장 할인 보기',
    'offerBody': '같은 용도의 다른 선택지를 바로 비교하실 수 있어요. 가격이나 구성만 가볍게 확인해보세요.',
}

DEFAULT_STATE_DECISION_PRIORITIES: Dict[str, Dict[str, int]] = {
    'activeShopping': {
        'offerPendingReview': 300,
        'offerCurrentCart': 280,
        'offerRepeatPurchase': 180,
        'currentCartHighImpact': 240,
        'recentScanPending': 220,
        'recentScanInCart': 180,
        'currentCartDefault': 160,
    },
    'postSave': {
        'offerPendingReview': 220,
        'offerCurrentCart': 250,
        'offerRepeatPurchase': 280,
        'recentScanInCart': 240,
        'currentCartDefault': 210,
        'currentCartHighImpact': 180,
        'recentScanPending': 160,
    },
    'idlePlanning': {
        'offerPendingReview': 150,
        'offerCurrentCart': 140,
        'offerRepeatPurchase': 220,
        'recentScanPending': 210,
        'currentCartDefault': 180,
        'recentScanInCart': 150,
        'currentCartHighImpact': 140,
    },
    'storeContext': {
        'offerPendingReview': 300,
        'offerCurrentCart': 320,
        'offerRepeatPurchase': 200,
        'currentCartHighImpact': 230,
        'recentScanInCart': 210,
        'currentCartDefault': 180,
        'recentScanPending': 150,
    },
}

DEFAULT_STATE_DECISION_MAX_COUNTS: Dict[str, Dict[str, int]] = {
    'activeShopping': {
        'offerPendingReview': 1,
        'offerCurrentCart': 1,
        'offerRepeatPurchase': 1,
        'recentScanPending': 1,
        'recentScanInCart': 1,
        'currentCartHighImpact': 1,
        'currentCartDefault': 1,
    },
    'postSave': {
        'offerPendingReview': 1,
        'offerCurrentCart': 1,
        'offerRepeatPurchase': 2,
        'recentScanPending': 1,
        'recentScanInCart': 2,
        'currentCartHighImpact': 1,
        'currentCartDefault': 2,
    },
    'idlePlanning': {
        'offerPendingReview': 1,
        'offerCurrentCart': 1,
        'offerRepeatPurchase': 2,
        'recentScanPending': 2,
        'recentScanInCart': 1,
        'currentCartHighImpact': 1,
        'currentCartDefault': 1,
    },
    'storeContext': {
        'offerPendingReview': 1,
        'offerCurrentCart': 2,
        'offerRepeatPurchase': 1,
        'recentScanPending': 1,
        'recentScanInCart': 1,
        'currentCartHighImpact': 1,
        'currentCartDefault': 1,
    },
}

DEFAULT_EXPLORE_SETTINGS: Dict[str, Any] = {
    'enabledSections': ','.join(EXPLORE_SECTION_IDS),
    'sectionOrder': ','.join(EXPLORE_SECTION_IDS),
    'stateMode': 'auto',
    **DEFAULT_STATE_ORDERS,
    'stateRules': deepcopy(DEFAULT_STATE_RULES),
    'statePromoPolicies': deepcopy(DEFAULT_STATE_PROMO_POLICIES),
    'decisionCopy': deepcopy(DEFAULT_DECISION_COPY),
    'stateDecisionPriorities': deepcopy(DEFAULT_STATE_DECISION_PRIORITIES),
    'stateDecisionMaxCounts': deepcopy(DEFAULT_STATE_DECISION_MAX_COUNTS),
    'revisitRecentScanLimit': 3,
    'revisitCartItemLimit': 3,
    'revisitMaxItems': 4,
    'repeatMinCount': 2,
    'repeatMaxItems': 4,
    'offerMaxSlots': 3,
    'editorialRecommendationsEnabled': True,
    'naverShoppingResultsEnabled': True,
    'editorialRecommendationsTitle': '추천 제품',
    'editorialRecommendationsSubtitle': '지금 카트에 많이 담는 TOP5',
    'editorialRecommendationsCount': 5,
    'editorialRecommendationsPoolRaw': '',
    'editorialRecommendationsDisclaimer': '이 섹션에는 제휴 링크가 포함될 수 있으며, 이에 따라 일정 수수료를 제공받을 수 있어요.',
    'editorialRecommendationsHistory': [],
    'storeContextEnabled': False,
    'storeContextStoreName': '이마트 양재점',
    'storeContextPromoTitle': '지금 이 마트 세일',
    'storeContextPromoBody': '자주 사는 상품군과 겹치는 할인 행사부터 먼저 보여줘요.',
    'storeContextPromoCtaLabel': '행사 보기',
    'storeContextPromoSeedLabels': '유제품 세일,음료 행사,오늘의 마트 추천',
    'storeContextPromoSourceType': 'storeSale',
    'storeContextPromoSponsored': False,
    'storeContextPromoSponsorLabel': '',
    'storeContextPromoPriorityStart': 100,
    'storeContextMaxPromos': 3,
}


def _coerce_int(value: Any, default: int, minimum: int, maximum: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default
    return max(minimum, min(maximum, parsed))


def _coerce_bool(value: Any, default: bool) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized in ('1', 'true', 'yes', 'on'):
            return True
        if normalized in ('0', 'false', 'no', 'off'):
            return False
    return default


def _coerce_text(value: Any, default: str) -> str:
    if isinstance(value, str):
        normalized = value.strip()
        if normalized:
            return normalized
    return default


def _coerce_datetime_text(value: Any) -> str:
    if not isinstance(value, str):
        return ''
    normalized = value.strip()
    if not normalized:
        return ''
    normalized = normalized.replace('.', '-').replace('T', ' ')
    if re.fullmatch(r'\d{4}-\d{2}-\d{2}', normalized):
        normalized = f'{normalized} 00:00'
    try:
        parsed = datetime.fromisoformat(normalized.replace('Z', '+00:00').replace(' ', 'T'))
    except ValueError:
        return ''
    return parsed.strftime('%Y-%m-%d %H:%M')


def _now_admin_text() -> str:
    return datetime.now().strftime('%Y-%m-%d %H:%M')


def _coerce_display_slot(value: Any) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return 999
    if 1 <= parsed <= 10:
        return parsed
    return 999


def _coerce_state_mode(value: Any, default: str) -> str:
    if isinstance(value, str):
        normalized = value.strip()
        if normalized == 'auto' or normalized in EXPLORE_STATE_IDS:
            return normalized
    return default


def _normalize_section_list(value: Any, fallback: Iterable[str]) -> str:
    if isinstance(value, str):
        raw_parts = [part.strip() for part in value.split(',')]
    elif isinstance(value, list):
        raw_parts = [str(part).strip() for part in value]
    else:
        raw_parts = []

    allowed = set(EXPLORE_SECTION_IDS)
    normalized: List[str] = []
    for part in raw_parts:
        if not part or part not in allowed or part in normalized:
            continue
        normalized.append(part)

    if not normalized:
        normalized = list(fallback)
    return ','.join(normalized)


def _normalize_seed_labels(value: Any, fallback: str) -> str:
    if isinstance(value, str):
        raw_parts = [part.strip() for part in value.split(',')]
    elif isinstance(value, list):
        raw_parts = [str(part).strip() for part in value]
    else:
        raw_parts = []

    normalized: List[str] = []
    for part in raw_parts:
        if not part or part in normalized:
            continue
        normalized.append(part)

    if not normalized:
        return fallback
    return ','.join(normalized)


def _coerce_source_type(value: Any, default: str) -> str:
    normalized = str(value or '').strip()
    if normalized in {'storeSale', 'sponsoredPlacement', 'editorialCuration'}:
        return normalized
    return default


def _looks_like_url(value: str) -> bool:
    parsed = urlparse(value.strip())
    return parsed.scheme in {'http', 'https'} and bool(parsed.netloc)


def _looks_like_image_url(value: str) -> bool:
    lower = value.strip().lower()
    return any(ext in lower for ext in ('.jpg', '.jpeg', '.png', '.webp', '.gif', 'image', 'thumb'))


def _extract_iframe_src(value: str) -> str:
    matched = re.search(r'''<iframe[^>]+src=["']([^"']+)["']''', value, flags=re.IGNORECASE)
    return matched.group(1).strip() if matched else ''


def _extract_anchor_image_metadata(value: str) -> Dict[str, str]:
    href_match = re.search(r'''<a[^>]+href=["']([^"']+)["']''', value, flags=re.IGNORECASE)
    src_match = re.search(r'''<img[^>]+src=["']([^"']+)["']''', value, flags=re.IGNORECASE)
    alt_match = re.search(r'''<img[^>]+alt=["']([^"']+)["']''', value, flags=re.IGNORECASE)
    return {
        'href': href_match.group(1).strip() if href_match else '',
        'src': src_match.group(1).strip() if src_match else '',
        'alt': unescape(alt_match.group(1)).strip() if alt_match else '',
    }


def _metadata_from_url_query(url: str) -> Dict[str, Any]:
    parsed = urlparse(url)
    query = parse_qs(parsed.query)

    def first(*keys: str) -> str:
        for key in keys:
            values = query.get(key)
            if not values:
                continue
            value = str(values[0] or '').strip()
            if value:
                return unescape(value)
        return ''

    deeplink_url = first('link', 'linkUrl', 'url') or url
    thumbnail_url = first('productImage', 'image', 'thumbnailUrl')
    title = first('title', 'productDescription', 'productName')
    return {
        'title': title,
        'thumbnailUrl': thumbnail_url,
        'price': None,
        'provider': _provider_label_from_url(deeplink_url or url),
        'deeplinkUrl': deeplink_url,
        'url': deeplink_url,
    }


def _normalize_editorial_pool_raw(value: Any, default: str) -> str:
    if not isinstance(value, str):
        return default

    normalized_lines = [line.rstrip() for line in value.replace('\r\n', '\n').split('\n')]
    return '\n'.join(normalized_lines).strip()


class _EditorialMetadataParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.meta: Dict[str, str] = {}
        self._in_title = False
        self._title_chunks: List[str] = []

    @property
    def title(self) -> str:
        return ' '.join(part.strip() for part in self._title_chunks if part.strip()).strip()

    def handle_starttag(self, tag: str, attrs: List[tuple[str, Optional[str]]]) -> None:
        attrs_map = {key.lower(): (value or '').strip() for key, value in attrs}
        if tag.lower() == 'title':
            self._in_title = True
            return
        if tag.lower() != 'meta':
            return

        content = attrs_map.get('content', '').strip()
        if not content:
            return
        for key_name in ('property', 'name', 'itemprop'):
            key = attrs_map.get(key_name, '').strip().lower()
            if key and key not in self.meta:
                self.meta[key] = content

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == 'title':
            self._in_title = False

    def handle_data(self, data: str) -> None:
        if self._in_title:
            self._title_chunks.append(data)


def _parse_price_value(value: str) -> Optional[int]:
    digits = ''.join(ch for ch in value if ch.isdigit())
    if not digits:
        return None
    try:
        return int(digits)
    except ValueError:
        return None


def _provider_label_from_url(value: str) -> str:
    host = urlparse(value.strip()).netloc.lower()
    if 'coupang' in host or 'coupa.ng' in host:
        return '쿠팡'
    if '11st' in host:
        return '11번가'
    if 'naver' in host:
        return '네이버'
    if 'gmarket' in host:
        return 'G마켓'
    if 'auction' in host:
        return '옥션'
    if 'ssg' in host:
        return 'SSG'
    if 'kurly' in host:
        return '컬리'
    if 'lotteon' in host:
        return '롯데온'
    if 'emart' in host:
        return '이마트'
    if not host:
        return '추천'
    root = host.split(':', 1)[0].split('.')
    if len(root) >= 2:
        label = root[-2]
    else:
        label = root[0]
    return label.upper() if len(label) <= 4 else label.capitalize()


def _fetch_editorial_metadata(url: str) -> Dict[str, Any]:
    request = Request(
        url,
        headers={
            'User-Agent': 'Mozilla/5.0 (compatible; CartlyAdmin/1.0; +https://cartly.app)',
            'Accept-Language': 'ko,en;q=0.9',
        },
    )
    with urlopen(request, timeout=6) as response:
        final_url = response.geturl()
        raw_html = response.read(512 * 1024)
        charset = response.headers.get_content_charset() or 'utf-8'

    html = raw_html.decode(charset, errors='ignore')
    parser = _EditorialMetadataParser()
    parser.feed(html)
    query_metadata = _metadata_from_url_query(final_url)

    meta = parser.meta
    title = (
        meta.get('og:title')
        or meta.get('twitter:title')
        or meta.get('title')
        or parser.title
        or query_metadata.get('title')
    )
    thumbnail_url = (
        meta.get('og:image')
        or meta.get('twitter:image')
        or meta.get('image')
        or meta.get('thumbnailurl')
        or query_metadata.get('thumbnailUrl')
        or ''
    )
    if thumbnail_url:
        thumbnail_url = urljoin(final_url, thumbnail_url)

    price = None
    for key in (
        'product:price:amount',
        'og:price:amount',
        'price',
        'product:price',
        'twitter:data1',
    ):
        price = _parse_price_value(meta.get(key, ''))
        if price is not None:
            break

    if price is None:
        for pattern in (
            r'"salePrice"\s*:\s*"?([0-9][0-9,\.]*)"?',
            r'"finalPrice"\s*:\s*"?([0-9][0-9,\.]*)"?',
            r'"discountedPrice"\s*:\s*"?([0-9][0-9,\.]*)"?',
            r'"price"\s*:\s*"?([0-9][0-9,\.]*)"?',
            r'data-price\s*=\s*"([0-9][0-9,\.]*)"',
        ):
            matched = re.search(pattern, html, flags=re.IGNORECASE)
            if not matched:
                continue
            price = _parse_price_value(matched.group(1))
            if price is not None:
                break

    deeplink_url = str(query_metadata.get('deeplinkUrl') or final_url).strip()
    return {
        'title': unescape(title or '').strip(),
        'thumbnailUrl': thumbnail_url,
        'price': price,
        'provider': str(query_metadata.get('provider') or _provider_label_from_url(final_url)).strip(),
        'deeplinkUrl': deeplink_url,
        'url': deeplink_url,
    }


def _coerce_editorial_item(item: Any, item_index: int) -> Optional[Dict[str, Any]]:
    if not isinstance(item, dict):
        return None
    title = str(item.get('title') or '').strip() or f'추천 상품 {item_index}'
    thumbnail_url = str(item.get('thumbnailUrl') or '').strip()
    deeplink_url = str(item.get('deeplinkUrl') or item.get('url') or '').strip()
    provider = str(item.get('provider') or '').strip() or _provider_label_from_url(deeplink_url)
    price = item.get('price')
    if isinstance(price, str):
        price = _parse_price_value(price)
    elif isinstance(price, float):
        price = int(price)
    elif not isinstance(price, int):
        price = None
    return {
        'id': str(item.get('id') or f'editorial-pick-{item_index}').strip() or f'editorial-pick-{item_index}',
        'historyId': str(item.get('historyId') or '').strip(),
        'title': title,
        'price': price,
        'thumbnailUrl': thumbnail_url,
        'url': deeplink_url,
        'deeplinkUrl': deeplink_url,
        'provider': provider,
        'raw': str(item.get('raw') or '').strip(),
        'displaySlot': _coerce_display_slot(item.get('displaySlot')),
        'startsAt': _coerce_datetime_text(item.get('startsAt')),
        'endsAt': _coerce_datetime_text(item.get('endsAt')),
        'registeredAt': _coerce_datetime_text(item.get('registeredAt')),
        'deletedAt': _coerce_datetime_text(item.get('deletedAt')),
        'updatedAt': _coerce_datetime_text(item.get('updatedAt')),
    }


def _build_editorial_recommendations(raw_value: Any) -> List[Dict[str, Any]]:
    raw = raw_value if isinstance(raw_value, str) else ''
    results: List[Dict[str, Any]] = []
    seen_keys: set[str] = set()

    for line in raw.replace('\r\n', '\n').split('\n'):
        trimmed = line.strip()
        if not trimmed or trimmed.startswith('#'):
            continue

        iframe_src = _extract_iframe_src(trimmed)
        anchor_image = _extract_anchor_image_metadata(trimmed)
        normalized_line = iframe_src or trimmed
        parts = [part.strip() for part in normalized_line.split('|') if part.strip()]
        manual_title = anchor_image['alt'] if anchor_image['alt'] else ''
        deeplink_url = anchor_image['href'] if _looks_like_url(anchor_image['href']) else ''
        thumbnail_url = anchor_image['src'] if _looks_like_url(anchor_image['src']) else ''
        price: Optional[int] = None

        if deeplink_url:
            pass
        elif len(parts) == 1 and _looks_like_url(normalized_line):
            deeplink_url = normalized_line
        else:
            manual_title = manual_title or (parts[0] if parts else '')
            url_parts = [part for part in parts[1:] if _looks_like_url(part)]
            non_url_parts = [part for part in parts[1:] if not _looks_like_url(part)]

            for part in non_url_parts:
                if price is None:
                    price = _parse_price_value(part)

            if len(url_parts) >= 2:
                thumbnail_url = url_parts[0]
                deeplink_url = url_parts[-1]
            elif len(url_parts) == 1:
                if price is not None and _looks_like_image_url(url_parts[0]):
                    thumbnail_url = url_parts[0]
                else:
                    deeplink_url = url_parts[0]

        dedupe_key = deeplink_url or thumbnail_url or manual_title
        if not dedupe_key or dedupe_key in seen_keys:
            continue

        seen_keys.add(dedupe_key)
        item_index = len(results) + 1
        title = manual_title or f'추천 상품 {item_index}'
        provider = _provider_label_from_url(deeplink_url)
        results.append(
            {
                'id': f'editorial-pick-{item_index}',
                'title': title,
                'price': price,
                'thumbnailUrl': thumbnail_url,
                'url': deeplink_url,
                'deeplinkUrl': deeplink_url,
                'provider': provider,
                'displaySlot': 999,
                '_manualTitle': bool(manual_title),
                '_manualPrice': price is not None,
                '_manualThumbnail': bool(thumbnail_url),
            }
        )

    return results


def _enrich_editorial_recommendations(
    items: List[Dict[str, Any]],
    cached_items: Optional[List[Dict[str, Any]]] = None,
) -> List[Dict[str, Any]]:
    cache_by_url: Dict[str, Dict[str, Any]] = {}
    for index, item in enumerate(cached_items or [], start=1):
        coerced = _coerce_editorial_item(item, index)
        if coerced is None:
            continue
        key = coerced['deeplinkUrl'] or coerced['thumbnailUrl'] or coerced['title']
        if key:
            cache_by_url[key] = coerced

    enriched: List[Dict[str, Any]] = []
    coerced_cached_items = [
        coerced
        for item_index, raw_cached in enumerate(cached_items or [], start=1)
        for coerced in [_coerce_editorial_item(raw_cached, item_index)]
        if coerced is not None
    ]
    for index, item in enumerate(items, start=1):
        key = str(item.get('deeplinkUrl') or item.get('thumbnailUrl') or item.get('title') or '')
        cached = cache_by_url.get(key)
        positional_cached = coerced_cached_items[index - 1] if index - 1 < len(coerced_cached_items) else None
        final_title = str(item.get('title') or '').strip() or f'추천 상품 {index}'
        final_price = item.get('price')
        final_thumbnail = str(item.get('thumbnailUrl') or '').strip()
        final_url = str(item.get('deeplinkUrl') or item.get('url') or '').strip()
        final_provider = str(item.get('provider') or '').strip() or _provider_label_from_url(final_url)

        if cached is not None:
            if not item.get('_manualTitle') and cached.get('title'):
                final_title = str(cached['title']).strip() or final_title
            if not item.get('_manualPrice') and cached.get('price') is not None:
                final_price = cached.get('price')
            if not item.get('_manualThumbnail') and cached.get('thumbnailUrl'):
                final_thumbnail = str(cached['thumbnailUrl']).strip() or final_thumbnail
            if cached.get('deeplinkUrl'):
                final_url = str(cached['deeplinkUrl']).strip() or final_url
            if cached.get('provider'):
                final_provider = str(cached['provider']).strip() or final_provider

        needs_fetch = bool(final_url) and (
            (not item.get('_manualTitle') and final_title.startswith('추천 상품'))
            or (not item.get('_manualPrice') and final_price is None)
            or (not item.get('_manualThumbnail') and not final_thumbnail)
            or not final_provider
        )
        if needs_fetch:
            try:
                fetched = _fetch_editorial_metadata(final_url)
            except Exception:
                fetched = {}
            if fetched:
                if not item.get('_manualTitle') and fetched.get('title'):
                    final_title = str(fetched['title']).strip() or final_title
                if not item.get('_manualPrice') and fetched.get('price') is not None:
                    final_price = fetched.get('price')
                if not item.get('_manualThumbnail') and fetched.get('thumbnailUrl'):
                    final_thumbnail = str(fetched['thumbnailUrl']).strip() or final_thumbnail
                if fetched.get('deeplinkUrl'):
                    final_url = str(fetched['deeplinkUrl']).strip() or final_url
                if fetched.get('provider'):
                    final_provider = str(fetched['provider']).strip() or final_provider

        enriched.append(
            {
                'id': f'editorial-pick-{index}',
                'title': final_title or f'추천 상품 {index}',
                'price': final_price if isinstance(final_price, int) else _parse_price_value(str(final_price or '')),
                'thumbnailUrl': final_thumbnail,
                'url': final_url,
                'deeplinkUrl': final_url,
                'provider': final_provider or _provider_label_from_url(final_url),
                'raw': str(item.get('raw') or (cached or positional_cached or {}).get('raw') or '').strip(),
                'historyId': str(item.get('historyId') or (cached or positional_cached or {}).get('historyId') or '').strip(),
                'displaySlot': _coerce_display_slot(item.get('displaySlot') or (cached or positional_cached or {}).get('displaySlot')),
                'startsAt': _coerce_datetime_text(item.get('startsAt') or (cached or positional_cached or {}).get('startsAt')),
                'endsAt': _coerce_datetime_text(item.get('endsAt') or (cached or positional_cached or {}).get('endsAt')),
                'registeredAt': _coerce_datetime_text(item.get('registeredAt') or (cached or positional_cached or {}).get('registeredAt')),
                'deletedAt': _coerce_datetime_text(item.get('deletedAt') or (cached or positional_cached or {}).get('deletedAt')),
                'updatedAt': _coerce_datetime_text(item.get('updatedAt') or (cached or positional_cached or {}).get('updatedAt')),
            }
        )

    return enriched


def _normalize_state_rules(value: Any) -> Dict[str, Dict[str, int]]:
    payload = value if isinstance(value, dict) else {}
    normalized: Dict[str, Dict[str, int]] = {}

    for state in EXPLORE_STATE_IDS:
        state_payload = payload.get(state) if isinstance(payload.get(state), dict) else {}
        defaults = DEFAULT_STATE_RULES[state]
        state_rules: Dict[str, int] = {}
        for key, (_, minimum, maximum) in STATE_RULE_SPECS.items():
            state_rules[key] = _coerce_int(
                state_payload.get(key),
                defaults[key],
                minimum,
                maximum,
            )
        normalized[state] = state_rules

    return normalized


def _normalize_state_promo_policies(value: Any) -> Dict[str, Dict[str, Any]]:
    payload = value if isinstance(value, dict) else {}
    normalized: Dict[str, Dict[str, Any]] = {}

    for state in EXPLORE_STATE_IDS:
        state_payload = payload.get(state) if isinstance(payload.get(state), dict) else {}
        defaults = DEFAULT_STATE_PROMO_POLICIES[state]
        normalized[state] = {
            'allowSponsoredPromos': _coerce_bool(
                state_payload.get('allowSponsoredPromos'),
                defaults['allowSponsoredPromos'],
            ),
            'maxSponsoredPromos': _coerce_int(
                state_payload.get('maxSponsoredPromos'),
                defaults['maxSponsoredPromos'],
                0,
                12,
            ),
            'organicFirst': _coerce_bool(
                state_payload.get('organicFirst'),
                defaults['organicFirst'],
            ),
        }

    return normalized


def _normalize_decision_copy(value: Any) -> Dict[str, str]:
    payload = value if isinstance(value, dict) else {}
    normalized: Dict[str, str] = {}
    for key, fallback in DEFAULT_DECISION_COPY.items():
        normalized[key] = _coerce_text(payload.get(key), fallback)
    return normalized


def _normalize_state_decision_priorities(value: Any) -> Dict[str, Dict[str, int]]:
    payload = value if isinstance(value, dict) else {}
    normalized: Dict[str, Dict[str, int]] = {}
    for state in EXPLORE_STATE_IDS:
        state_payload = payload.get(state) if isinstance(payload.get(state), dict) else {}
        defaults = DEFAULT_STATE_DECISION_PRIORITIES[state]
        legacy_offer = state_payload.get('offer')
        normalized[state] = {
            'offerPendingReview': _coerce_int(
                state_payload.get('offerPendingReview', legacy_offer),
                defaults['offerPendingReview'],
                0,
                999,
            ),
            'offerCurrentCart': _coerce_int(
                state_payload.get('offerCurrentCart', legacy_offer),
                defaults['offerCurrentCart'],
                0,
                999,
            ),
            'offerRepeatPurchase': _coerce_int(
                state_payload.get('offerRepeatPurchase', legacy_offer),
                defaults['offerRepeatPurchase'],
                0,
                999,
            ),
            'recentScanPending': _coerce_int(
                state_payload.get('recentScanPending'),
                defaults['recentScanPending'],
                0,
                999,
            ),
            'recentScanInCart': _coerce_int(
                state_payload.get('recentScanInCart'),
                defaults['recentScanInCart'],
                0,
                999,
            ),
            'currentCartHighImpact': _coerce_int(
                state_payload.get('currentCartHighImpact'),
                defaults['currentCartHighImpact'],
                0,
                999,
            ),
            'currentCartDefault': _coerce_int(
                state_payload.get('currentCartDefault'),
                defaults['currentCartDefault'],
                0,
                999,
            ),
        }
    return normalized


def _normalize_state_decision_max_counts(value: Any) -> Dict[str, Dict[str, int]]:
    payload = value if isinstance(value, dict) else {}
    normalized: Dict[str, Dict[str, int]] = {}
    for state in EXPLORE_STATE_IDS:
        state_payload = payload.get(state) if isinstance(payload.get(state), dict) else {}
        defaults = DEFAULT_STATE_DECISION_MAX_COUNTS[state]
        legacy_offer = state_payload.get('offer')
        normalized[state] = {
            'offerPendingReview': _coerce_int(
                state_payload.get('offerPendingReview', legacy_offer),
                defaults['offerPendingReview'],
                0,
                4,
            ),
            'offerCurrentCart': _coerce_int(
                state_payload.get('offerCurrentCart', legacy_offer),
                defaults['offerCurrentCart'],
                0,
                4,
            ),
            'offerRepeatPurchase': _coerce_int(
                state_payload.get('offerRepeatPurchase', legacy_offer),
                defaults['offerRepeatPurchase'],
                0,
                4,
            ),
            'recentScanPending': _coerce_int(
                state_payload.get('recentScanPending'),
                defaults['recentScanPending'],
                0,
                4,
            ),
            'recentScanInCart': _coerce_int(
                state_payload.get('recentScanInCart'),
                defaults['recentScanInCart'],
                0,
                4,
            ),
            'currentCartHighImpact': _coerce_int(
                state_payload.get('currentCartHighImpact'),
                defaults['currentCartHighImpact'],
                0,
                4,
            ),
            'currentCartDefault': _coerce_int(
                state_payload.get('currentCartDefault'),
                defaults['currentCartDefault'],
                0,
                4,
            ),
        }
    return normalized


def _build_store_context_promos(data: Dict[str, Any]) -> List[Dict[str, Any]]:
    # Cartly should not surface preview/demo store-sale content to customers.
    # Until a real nearby-store sale ingestion pipeline exists, keep this empty.
    return []


def normalize_explore_settings(
    payload: Optional[Dict[str, Any]],
    *,
    enrich_editorial_items: bool = False,
    cached_editorial_items: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    data = deepcopy(DEFAULT_EXPLORE_SETTINGS)
    if isinstance(payload, dict):
        data.update(payload)

    default_sections = DEFAULT_EXPLORE_SETTINGS['enabledSections'].split(',')
    data['enabledSections'] = _normalize_section_list(
        data.get('enabledSections'),
        default_sections,
    )
    data['sectionOrder'] = _normalize_section_list(
        data.get('sectionOrder'),
        data['enabledSections'].split(','),
    )
    data['stateMode'] = _coerce_state_mode(
        data.get('stateMode'),
        DEFAULT_EXPLORE_SETTINGS['stateMode'],
    )
    for key, fallback in DEFAULT_STATE_ORDERS.items():
        data[key] = _normalize_section_list(
            data.get(key),
            fallback.split(','),
        )
    data['stateRules'] = _normalize_state_rules(data.get('stateRules'))
    data['statePromoPolicies'] = _normalize_state_promo_policies(
        data.get('statePromoPolicies'),
    )
    data['decisionCopy'] = _normalize_decision_copy(data.get('decisionCopy'))
    data['stateDecisionPriorities'] = _normalize_state_decision_priorities(
        data.get('stateDecisionPriorities'),
    )
    data['stateDecisionMaxCounts'] = _normalize_state_decision_max_counts(
        data.get('stateDecisionMaxCounts'),
    )
    data['revisitRecentScanLimit'] = _coerce_int(
        data.get('revisitRecentScanLimit'),
        DEFAULT_EXPLORE_SETTINGS['revisitRecentScanLimit'],
        0,
        8,
    )
    data['revisitCartItemLimit'] = _coerce_int(
        data.get('revisitCartItemLimit'),
        DEFAULT_EXPLORE_SETTINGS['revisitCartItemLimit'],
        0,
        8,
    )
    data['revisitMaxItems'] = _coerce_int(
        data.get('revisitMaxItems'),
        DEFAULT_EXPLORE_SETTINGS['revisitMaxItems'],
        0,
        12,
    )
    data['repeatMinCount'] = _coerce_int(
        data.get('repeatMinCount'),
        DEFAULT_EXPLORE_SETTINGS['repeatMinCount'],
        1,
        10,
    )
    data['repeatMaxItems'] = _coerce_int(
        data.get('repeatMaxItems'),
        DEFAULT_EXPLORE_SETTINGS['repeatMaxItems'],
        0,
        12,
    )
    data['offerMaxSlots'] = _coerce_int(
        data.get('offerMaxSlots'),
        DEFAULT_EXPLORE_SETTINGS['offerMaxSlots'],
        0,
        12,
    )
    data['editorialRecommendationsEnabled'] = _coerce_bool(
        data.get('editorialRecommendationsEnabled'),
        DEFAULT_EXPLORE_SETTINGS['editorialRecommendationsEnabled'],
    )
    data['naverShoppingResultsEnabled'] = _coerce_bool(
        data.get('naverShoppingResultsEnabled'),
        DEFAULT_EXPLORE_SETTINGS['naverShoppingResultsEnabled'],
    )
    data['editorialRecommendationsTitle'] = _coerce_text(
        data.get('editorialRecommendationsTitle'),
        DEFAULT_EXPLORE_SETTINGS['editorialRecommendationsTitle'],
    )
    data['editorialRecommendationsSubtitle'] = _coerce_text(
        data.get('editorialRecommendationsSubtitle'),
        DEFAULT_EXPLORE_SETTINGS['editorialRecommendationsSubtitle'],
    )
    data['editorialRecommendationsCount'] = _coerce_int(
        data.get('editorialRecommendationsCount'),
        DEFAULT_EXPLORE_SETTINGS['editorialRecommendationsCount'],
        1,
        50,
    )
    data['editorialRecommendationsPoolRaw'] = _normalize_editorial_pool_raw(
        data.get('editorialRecommendationsPoolRaw'),
        DEFAULT_EXPLORE_SETTINGS['editorialRecommendationsPoolRaw'],
    )
    data['editorialRecommendationsDisclaimer'] = str(
        data.get('editorialRecommendationsDisclaimer')
        or DEFAULT_EXPLORE_SETTINGS['editorialRecommendationsDisclaimer']
    ).strip()
    parsed_editorial_items = _build_editorial_recommendations(
        data['editorialRecommendationsPoolRaw']
    )
    existing_cached_items = cached_editorial_items
    if existing_cached_items is None and isinstance(payload, dict):
        raw_cached_items = payload.get('editorialRecommendationsItems')
        if isinstance(raw_cached_items, list):
            existing_cached_items = [
                item for item in raw_cached_items if isinstance(item, dict)
            ]
    data['editorialRecommendationsItems'] = (
        _enrich_editorial_recommendations(
            parsed_editorial_items,
            cached_items=existing_cached_items,
        )
        if enrich_editorial_items
        else [
            coerced
            for index, item in enumerate(
                existing_cached_items or parsed_editorial_items,
                start=1,
            )
            for coerced in [_coerce_editorial_item(item, index)]
            if coerced is not None
        ]
    )
    data['editorialRecommendationsHistory'] = _normalize_editorial_history(
        data.get('editorialRecommendationsHistory')
    )
    data['storeContextEnabled'] = _coerce_bool(
        data.get('storeContextEnabled'),
        DEFAULT_EXPLORE_SETTINGS['storeContextEnabled'],
    )
    data['storeContextStoreName'] = _coerce_text(
        data.get('storeContextStoreName'),
        DEFAULT_EXPLORE_SETTINGS['storeContextStoreName'],
    )
    data['storeContextPromoTitle'] = _coerce_text(
        data.get('storeContextPromoTitle'),
        DEFAULT_EXPLORE_SETTINGS['storeContextPromoTitle'],
    )
    data['storeContextPromoBody'] = _coerce_text(
        data.get('storeContextPromoBody'),
        DEFAULT_EXPLORE_SETTINGS['storeContextPromoBody'],
    )
    data['storeContextPromoCtaLabel'] = _coerce_text(
        data.get('storeContextPromoCtaLabel'),
        DEFAULT_EXPLORE_SETTINGS['storeContextPromoCtaLabel'],
    )
    data['storeContextPromoSeedLabels'] = _normalize_seed_labels(
        data.get('storeContextPromoSeedLabels'),
        DEFAULT_EXPLORE_SETTINGS['storeContextPromoSeedLabels'],
    )
    data['storeContextPromoSourceType'] = _coerce_source_type(
        data.get('storeContextPromoSourceType'),
        DEFAULT_EXPLORE_SETTINGS['storeContextPromoSourceType'],
    )
    data['storeContextPromoSponsored'] = _coerce_bool(
        data.get('storeContextPromoSponsored'),
        DEFAULT_EXPLORE_SETTINGS['storeContextPromoSponsored'],
    )
    data['storeContextPromoSponsorLabel'] = _coerce_text(
        data.get('storeContextPromoSponsorLabel'),
        DEFAULT_EXPLORE_SETTINGS['storeContextPromoSponsorLabel'],
    )
    data['storeContextPromoPriorityStart'] = _coerce_int(
        data.get('storeContextPromoPriorityStart'),
        DEFAULT_EXPLORE_SETTINGS['storeContextPromoPriorityStart'],
        0,
        1000,
    )
    data['storeContextMaxPromos'] = _coerce_int(
        data.get('storeContextMaxPromos'),
        DEFAULT_EXPLORE_SETTINGS['storeContextMaxPromos'],
        0,
        12,
    )
    data['storeContextPromos'] = _build_store_context_promos(data)
    return data


def _editorial_items_need_refresh(items: Optional[List[Dict[str, Any]]]) -> bool:
    if not items:
        return True
    for item in items:
        if not isinstance(item, dict):
            return True
        title = str(item.get('title') or '').strip()
        price = item.get('price')
        thumbnail = str(item.get('thumbnailUrl') or '').strip()
        provider = str(item.get('provider') or '').strip()
        if not title or title.startswith('추천 상품'):
            return True
        if not thumbnail:
            return True
        if not provider or provider == '쿠팡 추천':
            return True
    return False


def _normalize_editorial_history(value: Any) -> List[Dict[str, Any]]:
    if not isinstance(value, list):
        return []
    normalized: List[Dict[str, Any]] = []
    for index, item in enumerate(value, start=1):
        coerced = _coerce_editorial_item(item, index)
        if coerced is None:
            continue
        history_id = str(item.get('historyId') or coerced.get('historyId') or f'editorial-history-{uuid4().hex[:12]}').strip()
        normalized.append({
            **coerced,
            'historyId': history_id,
            'registeredAt': _coerce_datetime_text(item.get('registeredAt') or coerced.get('registeredAt')),
            'deletedAt': _coerce_datetime_text(item.get('deletedAt') or coerced.get('deletedAt')),
            'updatedAt': _coerce_datetime_text(item.get('updatedAt') or coerced.get('updatedAt')),
        })
    return normalized


def _apply_editorial_history(
    normalized: Dict[str, Any],
    current_payload: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    next_items = [
        coerced
        for index, item in enumerate(normalized.get('editorialRecommendationsItems') or [], start=1)
        for coerced in [_coerce_editorial_item(item, index)]
        if coerced is not None
    ]
    current_history = _normalize_editorial_history((current_payload or {}).get('editorialRecommendationsHistory'))
    history_by_id = {
        str(item.get('historyId') or '').strip(): dict(item)
        for item in current_history
        if str(item.get('historyId') or '').strip()
    }
    now_text = _now_admin_text()
    active_history_ids: set[str] = set()
    finalized_items: List[Dict[str, Any]] = []

    for index, item in enumerate(next_items, start=1):
        history_id = str(item.get('historyId') or '').strip() or f'editorial-history-{uuid4().hex[:12]}'
        existing = history_by_id.get(history_id, {})
        registered_at = _coerce_datetime_text(item.get('registeredAt') or existing.get('registeredAt')) or now_text
        starts_at = _coerce_datetime_text(item.get('startsAt') or existing.get('startsAt') or registered_at) or registered_at
        finalized_item = {
            **item,
            'id': str(item.get('id') or f'editorial-pick-{index}').strip() or f'editorial-pick-{index}',
            'historyId': history_id,
            'registeredAt': registered_at,
            'startsAt': starts_at,
            'deletedAt': '',
            'updatedAt': now_text,
        }
        finalized_items.append(finalized_item)
        history_by_id[history_id] = {
            **existing,
            **finalized_item,
            'historyId': history_id,
            'registeredAt': registered_at,
            'startsAt': starts_at,
            'deletedAt': '',
            'updatedAt': now_text,
        }
        active_history_ids.add(history_id)

    for history_id, record in list(history_by_id.items()):
        if history_id in active_history_ids:
            continue
        if record.get('deletedAt'):
            continue
        history_by_id[history_id] = {
            **record,
            'deletedAt': now_text,
            'updatedAt': now_text,
        }

    history_list = sorted(
        history_by_id.values(),
        key=lambda item: (
            _coerce_datetime_text(item.get('registeredAt')),
            _coerce_datetime_text(item.get('updatedAt')),
        ),
        reverse=True,
    )
    normalized['editorialRecommendationsItems'] = finalized_items
    normalized['editorialRecommendationsHistory'] = history_list
    return normalized


def resolve_editorial_recommendation_item(payload: Dict[str, Any]) -> Dict[str, Any]:
    raw = str(payload.get('raw') or '').strip()
    item_id = str(payload.get('id') or 'editorial-pick-1').strip() or 'editorial-pick-1'
    starts_at = _coerce_datetime_text(payload.get('startsAt'))
    ends_at = _coerce_datetime_text(payload.get('endsAt'))
    parsed_items = _build_editorial_recommendations(raw)
    cached_item = {
        'id': item_id,
        'historyId': str(payload.get('historyId') or '').strip(),
        'raw': raw,
        'displaySlot': _coerce_display_slot(payload.get('displaySlot')),
        'startsAt': starts_at,
        'endsAt': ends_at,
    }
    if parsed_items:
        parsed_items[0]['id'] = item_id
        parsed_items[0]['historyId'] = cached_item['historyId']
        parsed_items[0]['raw'] = raw
        parsed_items[0]['displaySlot'] = cached_item['displaySlot']
        parsed_items[0]['startsAt'] = starts_at
        parsed_items[0]['endsAt'] = ends_at
        enriched = _enrich_editorial_recommendations(parsed_items, cached_items=[cached_item])
        if enriched:
            enriched[0]['id'] = item_id
            enriched[0]['historyId'] = cached_item['historyId']
            enriched[0]['raw'] = raw
            enriched[0]['displaySlot'] = cached_item['displaySlot']
            enriched[0]['startsAt'] = starts_at
            enriched[0]['endsAt'] = ends_at
            coerced = _coerce_editorial_item(enriched[0], 1)
            if coerced is not None:
                return coerced
    return {
        'id': item_id,
        'title': '',
        'price': None,
        'thumbnailUrl': '',
        'url': '',
        'deeplinkUrl': '',
        'provider': '',
        'raw': raw,
        'displaySlot': _coerce_display_slot(payload.get('displaySlot')),
        'startsAt': starts_at,
        'endsAt': ends_at,
    }


def _safe_event_props_dict(row: AppEvent) -> Dict[str, Any]:
    raw = row.event_props_json
    if not raw:
        return {}
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def _editorial_metrics_by_item(db: OrmSession) -> Dict[str, Dict[str, int]]:
    metrics: Dict[str, Dict[str, int]] = {}
    relevant_names = {
        'explore_editorial_alt_recommended',
        'explore_editorial_pick_impression',
        'explore_editorial_pick_click',
        'explore_editorial_alt_click',
    }
    recent_threshold = datetime.utcnow() - timedelta(days=90)
    rows = (
        db.query(AppEvent)
        .filter(AppEvent.event_name.in_(tuple(relevant_names)))
        .filter(AppEvent.created_at >= recent_threshold)
        .all()
    )
    for row in rows:
        props = _safe_event_props_dict(row)
        item_id = str(props.get('itemId') or '').strip()
        if not item_id:
            continue
        bucket = metrics.setdefault(
            item_id,
            {
                'alternativeRecommendedCount': 0,
                'editorialImpressionCount': 0,
                'editorialClickCount': 0,
                'alternativeClickCount': 0,
            },
        )
        if row.event_name == 'explore_editorial_alt_recommended':
            bucket['alternativeRecommendedCount'] += 1
        elif row.event_name == 'explore_editorial_pick_impression':
            bucket['editorialImpressionCount'] += 1
        elif row.event_name == 'explore_editorial_pick_click':
            bucket['editorialClickCount'] += 1
        elif row.event_name == 'explore_editorial_alt_click':
            bucket['alternativeClickCount'] += 1
    return metrics


def _rank_editorial_recommendation_items(
    db: OrmSession,
    items: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    metrics_by_item = _editorial_metrics_by_item(db)
    ranked: List[Dict[str, Any]] = []

    for index, item in enumerate(items, start=1):
        item_id = str(item.get('id') or '').strip()
        stats = metrics_by_item.get(
            item_id,
            {
                'alternativeRecommendedCount': 0,
                'editorialImpressionCount': 0,
                'editorialClickCount': 0,
                'alternativeClickCount': 0,
            },
        )
        display_slot = _coerce_display_slot(item.get('displaySlot'))
        ranking_score = (
            stats['alternativeRecommendedCount'] * 7
            + stats['editorialClickCount'] * 12
            + stats['alternativeClickCount'] * 5
            + min(stats['editorialImpressionCount'], 20)
        )
        ranked.append(
            {
                **item,
                'rankingScore': ranking_score,
                'rankingStats': stats,
                '_originalIndex': index,
                '_displaySlot': display_slot,
            }
        )

    ranked.sort(
        key=lambda item: (
            -int(item.get('rankingScore') or 0),
            -int(((item.get('rankingStats') or {}).get('alternativeRecommendedCount') or 0)),
            -int(((item.get('rankingStats') or {}).get('editorialClickCount') or 0)),
            int(item.get('_displaySlot') or 999),
            int(item.get('_originalIndex') or 0),
        )
    )

    finalized: List[Dict[str, Any]] = []
    for item in ranked:
        cleaned = dict(item)
        cleaned.pop('_originalIndex', None)
        cleaned.pop('_displaySlot', None)
        finalized.append(cleaned)
    return finalized


def get_explore_settings(db: OrmSession) -> Dict[str, Any]:
    setting = db.get(AppSetting, EXPLORE_SETTINGS_KEY)
    if setting is None:
        normalized = normalize_explore_settings(DEFAULT_EXPLORE_SETTINGS)
        normalized['editorialRecommendationsRankedItems'] = _rank_editorial_recommendation_items(
            db,
            normalized.get('editorialRecommendationsItems') or [],
        )
        return normalized

    try:
        payload = json.loads(setting.value_json)
    except json.JSONDecodeError:
        payload = None

    if not isinstance(payload, dict):
        normalized = normalize_explore_settings(None)
        normalized['editorialRecommendationsRankedItems'] = _rank_editorial_recommendation_items(
            db,
            normalized.get('editorialRecommendationsItems') or [],
        )
        return normalized

    raw_cached_items = payload.get('editorialRecommendationsItems')
    cached_items = [item for item in raw_cached_items if isinstance(item, dict)] if isinstance(raw_cached_items, list) else None
    if _editorial_items_need_refresh(cached_items):
        normalized = normalize_explore_settings(
            payload,
            enrich_editorial_items=True,
            cached_editorial_items=cached_items,
        )
        normalized['editorialRecommendationsRankedItems'] = _rank_editorial_recommendation_items(
            db,
            normalized.get('editorialRecommendationsItems') or [],
        )
        return normalized

    normalized = normalize_explore_settings(payload, cached_editorial_items=cached_items)
    normalized['editorialRecommendationsRankedItems'] = _rank_editorial_recommendation_items(
        db,
        normalized.get('editorialRecommendationsItems') or [],
    )
    return normalized


def save_explore_settings(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
    current_payload: Optional[Dict[str, Any]] = None
    setting = db.get(AppSetting, EXPLORE_SETTINGS_KEY)
    if setting is not None:
        try:
            loaded = json.loads(setting.value_json)
            if isinstance(loaded, dict):
                current_payload = loaded
        except json.JSONDecodeError:
            current_payload = None

    cached_items = None
    if current_payload is not None:
        raw_cached_items = current_payload.get('editorialRecommendationsItems')
        if isinstance(raw_cached_items, list):
            cached_items = [item for item in raw_cached_items if isinstance(item, dict)]

    normalized = normalize_explore_settings(
        payload,
        enrich_editorial_items=True,
        cached_editorial_items=cached_items,
    )
    normalized = _apply_editorial_history(normalized, current_payload)
    setting = db.get(AppSetting, EXPLORE_SETTINGS_KEY)
    if setting is None:
        setting = AppSetting(
            key=EXPLORE_SETTINGS_KEY,
            value_json=json.dumps(normalized, ensure_ascii=False),
            updated_at=datetime.utcnow(),
        )
        db.add(setting)
    else:
        setting.value_json = json.dumps(normalized, ensure_ascii=False)
        setting.updated_at = datetime.utcnow()
        db.add(setting)
    db.commit()
    return normalized
