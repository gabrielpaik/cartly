from __future__ import annotations

from dataclasses import dataclass
import re

_STOP_TOKENS = {
    '특가',
    '행사',
    '기획',
    '기획팩',
    '증정',
    '사은품',
    '무료배송',
    '번들',
    'bundle',
    'set',
    'pack',
    '대용량',
    '소용량',
    '정품',
    '국내산',
    '수입산',
    '추천',
    'best',
    'best상품',
    'hot',
}

_UNIT_TOKENS = {
    'ml',
    'l',
    'g',
    'kg',
    '개',
    '입',
    '팩',
    '봉',
    '병',
    '캔',
    '매',
    '세트',
}


@dataclass(frozen=True)
class ExploreIntentNormalization:
    raw_text: str
    normalized_query_text: str
    intent_key: str
    intent_tokens: list[str]


_TOKEN_CLEAN_RE = re.compile(r'[^0-9a-z가-힣]+')
_NUMBER_RE = re.compile(r'^\d+(?:\.\d+)?$')


def normalize_explore_intent(raw_text: str) -> ExploreIntentNormalization:
    base = ' '.join(
        _TOKEN_CLEAN_RE.sub(' ', (raw_text or '').lower().replace('ℓ', 'l')).split()
    )
    merged = _merge_unit_tokens(base.split(' ') if base else [])
    filtered = [token for token in merged if token and token not in _STOP_TOKENS]
    normalized_query_text = ' '.join(filtered).strip() or (raw_text or '').strip()
    intent_tokens = [_normalize_token(token) for token in filtered if _normalize_token(token)]
    intent_key = '|'.join(intent_tokens) or (raw_text or '').strip().lower()
    return ExploreIntentNormalization(
        raw_text=raw_text,
        normalized_query_text=normalized_query_text,
        intent_key=intent_key,
        intent_tokens=intent_tokens,
    )


def _merge_unit_tokens(tokens: list[str]) -> list[str]:
    merged: list[str] = []
    index = 0
    while index < len(tokens):
        current = _normalize_token(tokens[index])
        if not current:
            index += 1
            continue

        if index + 1 < len(tokens):
            next_token = _normalize_token(tokens[index + 1])
            if _is_number_token(current) and next_token in _UNIT_TOKENS:
                merged.append(f'{current}{next_token}')
                index += 2
                continue

        merged.append(current)
        index += 1
    return merged


def _is_number_token(token: str) -> bool:
    return bool(_NUMBER_RE.match(token))


def _normalize_token(token: str) -> str:
    return (token or '').strip().lower()
