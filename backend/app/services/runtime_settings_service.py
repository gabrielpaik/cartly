import json
from datetime import datetime
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting

RUNTIME_SETTINGS_KEY = 'runtime_settings'
DEFAULT_MY_PAGE_SECTION_ORDER = [
    'recentSaved',
    'monthlySummary',
    'allSavedHistory',
]
DEFAULT_RUNTIME_SETTINGS: Dict[str, Any] = {
    'receiptReminderDelayMinutes': 60,
    'myPageInsightsEnabled': True,
    'myPageSummaryMonths': 3,
    'myPageTopCategoriesCount': 3,
    'myPageTopItemsCount': 3,
    'myPageSectionOrder': DEFAULT_MY_PAGE_SECTION_ORDER,
    'myPageCategoryGroups': [
        {
            'id': 'food',
            'label': '식품',
            'keywords': ['우유', '계란', '바나나', '사과', '양파', '대파', '샐러드', '요거트', '과일', '채소', '쌀', '라면', '빵', '베이글', '과자', '쿠키', '초콜릿', '아이스크림', '시리얼', '주스', '커피', '물', '음료', '제로', '닭가슴살', '연어', '소고기', '돼지고기', '두부'],
        },
        {
            'id': 'life_health',
            'label': '생활/건강',
            'keywords': ['휴지', '키친타월', '세제', '샴푸', '린스', '주방', '비누', '칫솔', '치약', '마스크', '영양제', '건강식품', '세정', '청소'],
        },
        {
            'id': 'digital',
            'label': '디지털/가전',
            'keywords': ['이어폰', '헤드폰', '충전기', '케이블', '마우스', '키보드', '모니터', '노트북', '아이폰', '갤럭시', '가전', '청소기'],
        },
        {
            'id': 'fashion_clothes',
            'label': '패션의류',
            'keywords': ['티셔츠', '셔츠', '바지', '청바지', '원피스', '패딩', '잠옷', '양말', '속옷'],
        },
        {
            'id': 'fashion_goods',
            'label': '패션잡화',
            'keywords': ['운동화', '가방', '모자', '벨트', '지갑', '목걸이', '반지', '시계'],
        },
        {
            'id': 'beauty',
            'label': '화장품/미용',
            'keywords': ['토너', '로션', '크림', '선크림', '쿠션', '립밤', '마스크팩', '클렌징'],
        },
        {
            'id': 'furniture',
            'label': '가구/인테리어',
            'keywords': ['의자', '책상', '선반', '수납', '조명', '침구', '이불', '베개', '커튼'],
        },
        {
            'id': 'baby',
            'label': '출산/육아',
            'keywords': ['기저귀', '분유', '물티슈', '유아', '아기', '젖병', '이유식'],
        },
        {
            'id': 'sports',
            'label': '스포츠/레저',
            'keywords': ['요가', '덤벨', '텐트', '캠핑', '자전거', '축구', '농구', '러닝', '등산'],
        },
        {
            'id': 'leisure',
            'label': '여가/생활편의',
            'keywords': ['티켓', '쿠폰', '도서', '책', '문구', '반려동물', '사료', '여행', '공연'],
        },
    ],
}
RUNTIME_SETTINGS_FIELD_KEYS = tuple(DEFAULT_RUNTIME_SETTINGS.keys())


def _coerce_receipt_reminder_delay_minutes(value: Any) -> int:
    try:
        normalized = int(value)
    except (TypeError, ValueError):
        return DEFAULT_RUNTIME_SETTINGS['receiptReminderDelayMinutes']
    return max(1, normalized)


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


def _coerce_int(value: Any, default: int, minimum: int, maximum: int) -> int:
    try:
        normalized = int(value)
    except (TypeError, ValueError):
        return default
    return max(minimum, min(maximum, normalized))


def _coerce_text(value: Any, default: str) -> str:
    if isinstance(value, str):
        normalized = value.strip()
        if normalized:
            return normalized
    return default


def _normalize_keyword_list(value: Any) -> List[str]:
    if isinstance(value, list):
        candidates = value
    elif isinstance(value, str):
        candidates = value.split(',')
    else:
        candidates = []
    deduped: List[str] = []
    seen = set()
    for item in candidates:
        if not isinstance(item, str):
            continue
        keyword = item.strip()
        lowered = keyword.lower()
        if not keyword or lowered in seen:
            continue
        seen.add(lowered)
        deduped.append(keyword)
    return deduped


def _normalize_category_group(value: Any, index: int) -> Optional[Dict[str, Any]]:
    if not isinstance(value, dict):
        return None
    label = _coerce_text(value.get('label'), '')
    if not label:
        return None
    provided_id = _coerce_text(value.get('id'), '')
    normalized_id = provided_id or f'group_{index + 1}'
    keywords = _normalize_keyword_list(value.get('keywords'))
    return {
        'id': normalized_id,
        'label': label,
        'keywords': keywords,
    }


def _coerce_category_groups(value: Any) -> List[Dict[str, Any]]:
    source = value if isinstance(value, list) else DEFAULT_RUNTIME_SETTINGS['myPageCategoryGroups']
    groups: List[Dict[str, Any]] = []
    for index, item in enumerate(source):
        normalized = _normalize_category_group(item, index)
        if normalized is not None:
            groups.append(normalized)
    return groups or list(DEFAULT_RUNTIME_SETTINGS['myPageCategoryGroups'])


def _coerce_my_page_section_order(value: Any) -> List[str]:
    if isinstance(value, list):
        candidates = value
    elif isinstance(value, str):
        candidates = value.split(',')
    else:
        candidates = DEFAULT_MY_PAGE_SECTION_ORDER

    ordered: List[str] = []
    for item in candidates:
        if not isinstance(item, str):
            continue
        normalized = item.strip()
        if normalized not in DEFAULT_MY_PAGE_SECTION_ORDER:
            continue
        if normalized in ordered:
            continue
        ordered.append(normalized)

    for item in DEFAULT_MY_PAGE_SECTION_ORDER:
        if item not in ordered:
            ordered.append(item)

    return ordered


def normalize_runtime_settings(payload: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    source = payload if isinstance(payload, dict) else {}
    return {
        'receiptReminderDelayMinutes': _coerce_receipt_reminder_delay_minutes(
            source.get('receiptReminderDelayMinutes')
        ),
        'myPageInsightsEnabled': _coerce_bool(
            source.get('myPageInsightsEnabled'),
            DEFAULT_RUNTIME_SETTINGS['myPageInsightsEnabled'],
        ),
        'myPageSummaryMonths': _coerce_int(
            source.get('myPageSummaryMonths'),
            DEFAULT_RUNTIME_SETTINGS['myPageSummaryMonths'],
            1,
            12,
        ),
        'myPageTopCategoriesCount': _coerce_int(
            source.get('myPageTopCategoriesCount'),
            DEFAULT_RUNTIME_SETTINGS['myPageTopCategoriesCount'],
            1,
            8,
        ),
        'myPageTopItemsCount': _coerce_int(
            source.get('myPageTopItemsCount'),
            DEFAULT_RUNTIME_SETTINGS['myPageTopItemsCount'],
            1,
            8,
        ),
        'myPageSectionOrder': _coerce_my_page_section_order(
            source.get('myPageSectionOrder')
        ),
        'myPageCategoryGroups': _coerce_category_groups(
            source.get('myPageCategoryGroups')
        ),
    }


def get_runtime_settings(db: OrmSession) -> Dict[str, Any]:
    setting = db.get(AppSetting, RUNTIME_SETTINGS_KEY)
    if setting is None:
        return normalize_runtime_settings(DEFAULT_RUNTIME_SETTINGS)
    try:
        payload = json.loads(setting.value_json)
        if isinstance(payload, dict):
            return normalize_runtime_settings(payload)
    except json.JSONDecodeError:
        pass
    return normalize_runtime_settings(DEFAULT_RUNTIME_SETTINGS)


def save_runtime_settings(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
    current = get_runtime_settings(db)
    merged = dict(current)
    for key in RUNTIME_SETTINGS_FIELD_KEYS:
        if key in payload:
            merged[key] = payload[key]
    normalized = normalize_runtime_settings(merged)
    setting = db.get(AppSetting, RUNTIME_SETTINGS_KEY)
    if setting is None:
        setting = AppSetting(
            key=RUNTIME_SETTINGS_KEY,
            value_json=json.dumps(normalized, ensure_ascii=False),
            updated_at=datetime.utcnow(),
        )
        db.add(setting)
    else:
        setting.value_json = json.dumps(normalized, ensure_ascii=False)
        setting.updated_at = datetime.utcnow()
        db.add(setting)
    db.commit()
    db.refresh(setting)
    return normalized
