from __future__ import annotations

import re
from typing import Any, Dict, Optional

_NAVER_LARGE_CATEGORY_RULES: list[tuple[str, tuple[str, ...]]] = [
    ('출산/육아', ('기저귀', '물티슈', '분유', '젖병', '유아', '아기', '신생아', '베이비', '이유식', '유모차', '카시트', '아기띠')),
    ('식품', ('쌀', '떡', '라면', '과자', '스낵', '쿠키', '비스킷', '크래커', '쿠쿠다스', '새우깡', '오잉', '음료', '생수', '커피', '우유', '요거트', '치즈', '계란', '달걀', '닭가슴살', '고기', '소고기', '돼지고기', '과일', '바나나', '채소', '오이', '김치', '반찬', '장아찌', '소스', '마요', '마요네스', '오트', '오트밀', '오일', '식용유', '올리브유', '참기름', '들기름', '시리얼', '간식', '빵', '베이커리', '크루아상', '냉동', '만두', '햄', '소시지', '참치', '캔', '곡물', '견과', '비타민젤리', '프로틴바', '카레')),
    ('생활/건강', ('세제', '휴지', '화장지', '티슈', '샴푸', '린스', '바디워시', '비누', '칫솔', '치약', '면도기', '마스크', '건강식품', '영양제', '비타민', '오메가', '프로바이오틱스', '생리대', '청소', '수세미', '주방세제', '섬유유연제', '캡슐세제', '주방', '생활용품', '건강')),
    ('디지털/가전', ('아이폰', '갤럭시', '아이패드', '맥북', '노트북', '모니터', '키보드', '마우스', '이어폰', '헤드폰', '에어팟', '충전기', '케이블', '닌텐도', '플레이스테이션', '게임기', 'tv', '티비', '냉장고', '세탁기', '청소기', '전자레인지', '가전', '휴대폰', '스마트폰')),
    ('패션의류', ('자켓', '재킷', '점퍼', '티셔츠', '반팔', '긴팔', '셔츠', '바지', '청바지', '데님', '원피스', '치마', '스커트', '후드', '맨투맨', '니트', '코트', '패딩', '의류', '잠옷', '내의', '속옷', '레깅스')),
    ('패션잡화', ('가방', '백팩', '지갑', '벨트', '모자', '캡', '양말', '운동화', '구두', '샌들', '슬리퍼', '부츠', '스니커즈', '목걸이', '귀걸이', '반지', '팔찌', '주얼리', '안경', '선글라스', '시계')),
    ('화장품/미용', ('쿠션', '파운데이션', '립', '틴트', '크림', '에센스', '선크림', '마스크팩', '클렌징', '로션', '스킨', '토너', '미용', '화장품', '메이크업', '향수')),
    ('스포츠/레저', ('텐트', '캠핑', '랜턴', '쉐이드', '아이스박스', '침낭', '타프', '골프', '축구', '야구', '농구', '러닝', '헬스', '요가', '자전거', '등산', '낚시', '수영', '운동', '레저')),
    ('가구/인테리어', ('의자', '책상', '테이블', '소파', '침대', '매트리스', '서랍', '수납', '선반', '조명', '스탠드', '거울', '커튼', '카펫', '인테리어', '가구')),
    ('문구/사무용품', ('노트', '공책', '펜', '볼펜', '연필', '캘린더', '다이어리', '파일', '프린터', '복사용지', '문구', '사무용품')),
    ('완구/취미', ('레고', '피규어', '보드게임', '퍼즐', '포켓몬카드', '장난감', '완구', '프라모델', '취미')),
    ('자동차용품', ('엔진오일', '와이퍼', '차량용', '자동차', '카매트', '블랙박스', '타이어', '세차')),
    ('반려동물', ('사료', '간식캔', '강아지', '고양이', '반려동물', '캣', '펫', '모래', '배변패드')),
    ('도서', ('도서', '책', '문제집', '소설', '에세이', '만화책')),
]


_DEF_SOURCE = 'keyword-rule-v1'
_MANUAL_SOURCE = 'admin-override-v1'


def list_large_category_options() -> list[str]:
    options = [category for category, _ in _NAVER_LARGE_CATEGORY_RULES]
    if '기타' not in options:
        options.append('기타')
    return options


def build_manual_category_meta(category: Optional[str]) -> Dict[str, Optional[str]]:
    normalized = (category or '').strip() or None
    if not normalized:
        return {
            'naverLargeCategory': None,
            'naverCategoryPath': None,
            'categorySource': _MANUAL_SOURCE,
        }
    return {
        'naverLargeCategory': normalized,
        'naverCategoryPath': normalized,
        'categorySource': _MANUAL_SOURCE,
    }


def _normalize_text(*parts: Any) -> str:
    merged = ' '.join(str(part).strip() for part in parts if isinstance(part, str) and part.strip())
    merged = merged.lower()
    merged = re.sub(r'\s+', ' ', merged)
    return merged.strip()


def infer_large_category(name: Optional[str], raw_text: Optional[str] = None, sku: Optional[str] = None) -> Dict[str, Optional[str]]:
    text = _normalize_text(name, raw_text, sku)
    if not text:
        return {
            'naverLargeCategory': None,
            'naverCategoryPath': None,
            'categorySource': _DEF_SOURCE,
        }

    for category, keywords in _NAVER_LARGE_CATEGORY_RULES:
        if any(keyword.lower() in text for keyword in keywords):
            return {
                'naverLargeCategory': category,
                'naverCategoryPath': category,
                'categorySource': _DEF_SOURCE,
            }

    return {
        'naverLargeCategory': '기타',
        'naverCategoryPath': '기타',
        'categorySource': _DEF_SOURCE,
    }


def enrich_result_with_category(result: Optional[Dict[str, Any]], meta: Optional[Dict[str, Any]] = None) -> Dict[str, Optional[str]]:
    result = result if isinstance(result, dict) else {}
    meta = meta if isinstance(meta, dict) else {}

    existing = meta.get('categoryMeta') if isinstance(meta.get('categoryMeta'), dict) else result.get('categoryMeta') if isinstance(result.get('categoryMeta'), dict) else None
    if isinstance(existing, dict):
        large = existing.get('naverLargeCategory') or existing.get('category')
        path = existing.get('naverCategoryPath') or existing.get('categoryPath')
        source = existing.get('categorySource') or existing.get('source')
        if any(isinstance(value, str) and value.strip() for value in (large, path)):
            return {
                'naverLargeCategory': large if isinstance(large, str) else None,
                'naverCategoryPath': path if isinstance(path, str) else None,
                'categorySource': source if isinstance(source, str) else _DEF_SOURCE,
            }

    return infer_large_category(
        result.get('name') if isinstance(result.get('name'), str) else None,
        result.get('rawText') if isinstance(result.get('rawText'), str) else None,
        result.get('sku') if isinstance(result.get('sku'), str) else None,
    )
