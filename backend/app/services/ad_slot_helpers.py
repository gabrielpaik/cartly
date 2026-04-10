import json
import re
from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import uuid4

from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..db.models import AdCampaign, AdSlot

DEFAULT_AD_SLOTS: List[Dict[str, Any]] = [
    {
        'slotKey': 'save_complete_sheet_1',
        'placementType': 'bottom_sheet',
        'status': 'active',
        'config': {
            'maxHeight': 88,
            'screen': 'save_complete',
            'position': 'after_summary_before_actions',
            'tone': 'benefit_native',
            'title': '다음 장보기도 더 가볍게',
            'message': '저장한 카트를 기준으로 혜택 상품을 이어서 볼 수 있어요.',
            'ctaLabel': '혜택 보기',
            'targetUrl': None,
            'imageUrl': None,
        },
    },
    {
        'slotKey': 'saved_inline_1',
        'placementType': 'inline',
        'status': 'active',
        'config': {
            'maxHeight': 104,
            'screen': 'saved_list',
            'position': 'after_first_card',
            'tone': 'benefit_native',
            'title': '지금 많이 담는 상품',
            'message': 'Saved 카트와 같이 보는 추천 배너 슬롯이야.',
            'ctaLabel': '자세히',
            'targetUrl': None,
            'imageUrl': None,
        },
    },
    {
        'slotKey': 'saved_inline_2',
        'placementType': 'inline',
        'status': 'active',
        'config': {
            'maxHeight': 104,
            'screen': 'saved_list',
            'position': 'after_third_card',
            'tone': 'benefit_native',
            'title': '같이 담기 좋은 상품',
            'message': 'Saved 리스트 중간 보조 프로모션 슬롯이야.',
            'ctaLabel': '확인',
            'targetUrl': None,
            'imageUrl': None,
        },
    },
    {
        'slotKey': 'my_perks_inline_1',
        'placementType': 'inline',
        'status': 'active',
        'config': {
            'slotLabel': 'My Perks Inline 1',
            'slotDescription': 'My 화면 계정 카드 아래에 들어가는 inline 광고 슬롯',
            'placementNote': 'My 화면 계정 카드 아래 · 96px',
            'maxHeight': 96,
            'screen': 'my',
            'position': 'below_account_card',
            'tone': 'soft_promo',
            'title': '멤버 혜택 확인',
            'message': 'My 화면용 보조 배너 슬롯이야.',
            'ctaLabel': '보기',
            'targetUrl': None,
            'imageUrl': None,
        },
    },
]


def _clean_string(value: Any, *, empty_as_none: bool = False) -> Any:
    if not isinstance(value, str):
        return None if empty_as_none else ''
    cleaned = value.strip()
    if empty_as_none:
        return cleaned or None
    return cleaned


def _normalize_slot_config(config: Dict[str, Any], *, include_reserved: bool = False) -> Dict[str, Any]:
    merged = {
        'slotLabel': _clean_string(config.get('slotLabel')),
        'slotDescription': _clean_string(config.get('slotDescription')),
        'placementNote': _clean_string(config.get('placementNote')),
        'maxHeight': config.get('maxHeight', 96),
        'screen': config.get('screen'),
        'position': config.get('position'),
        'tone': config.get('tone', 'benefit_native'),
        'title': _clean_string(config.get('title')),
        'message': _clean_string(config.get('message')),
        'ctaLabel': _clean_string(config.get('ctaLabel'), empty_as_none=True),
        'targetUrl': _clean_string(config.get('targetUrl'), empty_as_none=True),
        'imageUrl': _clean_string(config.get('imageUrl'), empty_as_none=True),
    }
    if include_reserved:
        merged.update(
            {
                'reservedTitle': _clean_string(config.get('reservedTitle')),
                'reservedMessage': _clean_string(config.get('reservedMessage')),
                'reservedCtaLabel': _clean_string(config.get('reservedCtaLabel'), empty_as_none=True),
                'reservedTargetUrl': _clean_string(config.get('reservedTargetUrl'), empty_as_none=True),
                'reservedImageUrl': _clean_string(config.get('reservedImageUrl'), empty_as_none=True),
                'exposureStartAt': _clean_string(config.get('exposureStartAt'), empty_as_none=True),
                'exposureEndAt': _clean_string(config.get('exposureEndAt'), empty_as_none=True),
                'reservationStartAt': _clean_string(config.get('reservationStartAt'), empty_as_none=True),
                'reservationEndAt': _clean_string(config.get('reservationEndAt'), empty_as_none=True),
                'liveCampaignId': _clean_string(config.get('liveCampaignId'), empty_as_none=True),
                'reservedCampaignId': _clean_string(config.get('reservedCampaignId'), empty_as_none=True),
            }
        )
    return merged


def _serialize_slot(row: AdSlot, fallback: Dict[str, Any]) -> Dict[str, Any]:
    config = fallback['config'].copy()
    if row.config_json:
        try:
            config.update(json.loads(row.config_json) or {})
        except Exception:
            pass
    config = _normalize_slot_config(config, include_reserved=True)
    return {
        'id': row.id,
        'slotKey': row.slot_key,
        'placementType': row.placement_type,
        'status': row.status,
        'createdAt': row.created_at.isoformat() if row.created_at else None,
        'updatedAt': row.updated_at.isoformat() if row.updated_at else None,
        'config': config,
    }


def _parse_optional_datetime(value: Any) -> Optional[datetime]:
    if not isinstance(value, str):
        return None
    cleaned = value.strip()
    if not cleaned:
        return None
    try:
        return datetime.fromisoformat(cleaned)
    except ValueError:
        return None


def _campaign_fields_from_config(config: Dict[str, Any], variant: str) -> Dict[str, Any]:
    if variant == 'reserved':
        return {
            'title': config.get('reservedTitle') or '',
            'message': config.get('reservedMessage') or '',
            'ctaLabel': config.get('reservedCtaLabel'),
            'targetUrl': config.get('reservedTargetUrl'),
            'imageUrl': config.get('reservedImageUrl'),
            'startAt': config.get('reservationStartAt'),
            'endAt': config.get('reservationEndAt'),
            'campaignId': config.get('reservedCampaignId'),
        }
    return {
        'title': config.get('title') or '',
        'message': config.get('message') or '',
        'ctaLabel': config.get('ctaLabel'),
        'targetUrl': config.get('targetUrl'),
        'imageUrl': config.get('imageUrl'),
        'startAt': config.get('exposureStartAt'),
        'endAt': config.get('exposureEndAt'),
        'campaignId': config.get('liveCampaignId'),
    }


def _has_campaign_content(fields: Dict[str, Any]) -> bool:
    return any(
        [
            fields.get('title'),
            fields.get('message'),
            fields.get('ctaLabel'),
            fields.get('targetUrl'),
            fields.get('imageUrl'),
            fields.get('startAt'),
            fields.get('endAt'),
        ]
    )


def _upsert_campaign_history(
    db: OrmSession,
    row: AdSlot,
    previous_config: Dict[str, Any],
    next_config: Dict[str, Any],
    variant: str,
) -> Dict[str, Any]:
    previous_fields = _campaign_fields_from_config(previous_config, variant)
    next_fields = _campaign_fields_from_config(next_config, variant)
    campaign_key_field = 'reservedCampaignId' if variant == 'reserved' else 'liveCampaignId'

    if not _has_campaign_content(next_fields):
        next_config[campaign_key_field] = None
        return next_config

    comparable_keys = ['title', 'message', 'ctaLabel', 'targetUrl', 'imageUrl', 'startAt', 'endAt']
    if previous_fields.get('campaignId') and all(previous_fields.get(key) == next_fields.get(key) for key in comparable_keys):
        next_config[campaign_key_field] = previous_fields.get('campaignId')
        return next_config

    previous_campaign_id = previous_fields.get('campaignId')
    if previous_campaign_id:
        previous_campaign = db.get(AdCampaign, previous_campaign_id)
        if previous_campaign and previous_campaign.slot_id == row.id:
            previous_campaign.status = 'cancelled' if variant == 'reserved' else 'ended'
            if previous_campaign.end_at is None:
                previous_campaign.end_at = _parse_optional_datetime(previous_fields.get('endAt')) or datetime.utcnow()
            db.add(previous_campaign)

    campaign = AdCampaign(
        id=str(uuid4()),
        slot_id=row.id,
        variant=variant,
        status='scheduled' if variant == 'reserved' else 'live',
        title=next_fields.get('title') or '',
        message=next_fields.get('message') or '',
        cta_label=next_fields.get('ctaLabel'),
        target_url=next_fields.get('targetUrl'),
        image_url=next_fields.get('imageUrl'),
        start_at=_parse_optional_datetime(next_fields.get('startAt')),
        end_at=_parse_optional_datetime(next_fields.get('endAt')),
    )
    db.add(campaign)
    next_config[campaign_key_field] = campaign.id
    return next_config


def _ensure_campaign_links_for_row(db: OrmSession, row: AdSlot, fallback: Dict[str, Any]) -> None:
    base_config = fallback['config'].copy()
    if row.config_json:
        try:
            base_config.update(json.loads(row.config_json) or {})
        except Exception:
            pass

    normalized = _normalize_slot_config(base_config, include_reserved=True)
    changed = False

    if _has_campaign_content(_campaign_fields_from_config(normalized, 'live')) and not normalized.get('liveCampaignId'):
        normalized = _upsert_campaign_history(db, row, normalized, normalized, 'live')
        changed = True

    if _has_campaign_content(_campaign_fields_from_config(normalized, 'reserved')) and not normalized.get('reservedCampaignId'):
        normalized = _upsert_campaign_history(db, row, normalized, normalized, 'reserved')
        changed = True

    if changed:
        row.config_json = json.dumps(_normalize_slot_config(normalized, include_reserved=True), ensure_ascii=False)
        db.add(row)


def _parse_optional_date_range_start(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromisoformat(f'{value.strip()}T00:00:00')
    except ValueError:
        return None


def _parse_optional_date_range_end(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromisoformat(f'{value.strip()}T23:59:59')
    except ValueError:
        return None


def _campaign_matches_filters(
    campaign: AdCampaign,
    *,
    query: Optional[str] = None,
    variant: Optional[str] = None,
    status: Optional[str] = None,
    period_from: Optional[str] = None,
    period_to: Optional[str] = None,
) -> bool:
    if variant and variant != 'all' and campaign.variant != variant:
        return False
    if status and status != 'all' and campaign.status != status:
        return False

    if query:
        q = query.strip().lower()
        if q:
            haystacks = [campaign.title, campaign.message, campaign.cta_label, campaign.target_url]
            if not any((value or '').lower().find(q) >= 0 for value in haystacks):
                return False

    range_start = _parse_optional_date_range_start(period_from)
    range_end = _parse_optional_date_range_end(period_to)
    campaign_start = campaign.start_at or campaign.created_at
    campaign_end = campaign.end_at or campaign.created_at
    if range_start and campaign_end and campaign_end < range_start:
        return False
    if range_end and campaign_start and campaign_start > range_end:
        return False

    return True


def _safe_xlsx_filename(value: str) -> str:
    cleaned = re.sub(r'[^A-Za-z0-9._-]+', '-', value.strip())
    return cleaned.strip('-') or 'wimc-ad-campaign'


def _campaign_image_formula_url(image_url: Optional[str]) -> Optional[str]:
    if not image_url:
        return None
    trimmed = image_url.strip()
    if not trimmed:
        return None
    if trimmed.startswith('http://') or trimmed.startswith('https://'):
        return trimmed
    if trimmed.startswith('/'):
        return f"{settings.api_base_url.rstrip('/')}{trimmed}"
    return trimmed
