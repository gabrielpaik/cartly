import json
from copy import deepcopy
from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting

EXPLORE_SETTINGS_KEY = 'explore_admin_settings'
EXPLORE_SECTION_IDS = (
    'heroSummary',
    'decisionInbox',
    'revisitItems',
    'repeatCandidates',
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
    'postSaveSectionOrder': 'savedContext,decisionInbox,repeatCandidates,offerSlots',
    'idlePlanningSectionOrder': 'savedContext,repeatCandidates,offerSlots',
    'storeContextSectionOrder': 'storeContextPromo,savedContext,repeatCandidates,offerSlots',
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
    store_name = data['storeContextStoreName']
    cta_label = data['storeContextPromoCtaLabel']
    body = data['storeContextPromoBody']
    state_rules = data.get('stateRules') if isinstance(data.get('stateRules'), dict) else {}
    store_state_rules = state_rules.get('storeContext') if isinstance(state_rules.get('storeContext'), dict) else {}
    count = _coerce_int(
        store_state_rules.get('storeContextMaxPromos'),
        data['storeContextMaxPromos'],
        0,
        12,
    )
    source_type = data['storeContextPromoSourceType']
    is_sponsored = data['storeContextPromoSponsored']
    sponsor_label = data['storeContextPromoSponsorLabel']
    priority_start = data['storeContextPromoPriorityStart']
    seed_labels = [
        part.strip()
        for part in str(data.get('storeContextPromoSeedLabels') or '').split(',')
        if part.strip()
    ]
    if not seed_labels:
        seed_labels = [
            '유제품 세일',
            '음료 행사',
            '오늘의 마트 추천',
        ]

    promos: List[Dict[str, Any]] = []
    for index, seed in enumerate(seed_labels[:count]):
        promo_is_sponsored = is_sponsored and index == 0
        promos.append(
            {
                'id': f'store-promo-{index + 1}',
                'title': f'{seed} 확인',
                'body': body,
                'badgeLabel': seed,
                'storeName': store_name,
                'ctaLabel': cta_label,
                'placementLabel': '매장 프로모션',
                'intentHint': '같은 구매 의도 기준',
                'source': 'store-context-preview',
                'sourceType': 'sponsoredPlacement' if promo_is_sponsored else source_type,
                'priority': max(0, priority_start - (index * 10)),
                'isSponsored': promo_is_sponsored,
                'sponsorLabel': sponsor_label if promo_is_sponsored and sponsor_label else '',
            }
        )
    return promos


def normalize_explore_settings(payload: Optional[Dict[str, Any]]) -> Dict[str, Any]:
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


def get_explore_settings(db: OrmSession) -> Dict[str, Any]:
    setting = db.get(AppSetting, EXPLORE_SETTINGS_KEY)
    if setting is None:
        return deepcopy(DEFAULT_EXPLORE_SETTINGS)

    try:
        payload = json.loads(setting.value_json)
    except json.JSONDecodeError:
        payload = None
    return normalize_explore_settings(payload if isinstance(payload, dict) else None)


def save_explore_settings(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
    normalized = normalize_explore_settings(payload)
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
