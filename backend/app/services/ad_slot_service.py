import io
import json
from typing import Any, Dict, List, Optional

from openpyxl import Workbook
from openpyxl.styles import Font
from sqlalchemy import func, select
from sqlalchemy.orm import Session as OrmSession

from ..db.models import AdCampaign, AdClick, AdImpression, AdSlot
from .ad_slot_helpers import (
    DEFAULT_AD_SLOTS,
    _campaign_image_formula_url,
    _campaign_matches_filters,
    _ensure_campaign_links_for_row,
    _normalize_slot_config,
    _safe_xlsx_filename,
    _serialize_slot,
    _upsert_campaign_history,
)


def ensure_default_ad_slots(db: OrmSession) -> None:
    existing = {row.slot_key: row for row in db.scalars(select(AdSlot)).all()}
    dirty = False
    for slot in DEFAULT_AD_SLOTS:
        if slot['slotKey'] not in existing:
            db.add(
                AdSlot(
                    slot_key=slot['slotKey'],
                    placement_type=slot['placementType'],
                    status=slot['status'],
                    config_json=json.dumps(slot['config'], ensure_ascii=False),
                )
            )
            dirty = True
    if dirty:
        db.commit()


def list_ad_slots(db: OrmSession) -> List[Dict[str, Any]]:
    ensure_default_ad_slots(db)
    rows = db.scalars(select(AdSlot).order_by(AdSlot.created_at.asc())).all()
    defaults = {slot['slotKey']: slot for slot in DEFAULT_AD_SLOTS}
    dirty = False
    for row in rows:
        if row.slot_key in defaults:
            before = row.config_json
            _ensure_campaign_links_for_row(db, row, defaults[row.slot_key])
            if row.config_json != before:
                dirty = True
    if dirty:
        db.commit()
        for row in rows:
            db.refresh(row)
    return [_serialize_slot(row, defaults[row.slot_key]) for row in rows if row.slot_key in defaults]


def update_ad_slot(db: OrmSession, slot_key: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    ensure_default_ad_slots(db)
    row = db.scalar(select(AdSlot).where(AdSlot.slot_key == slot_key))
    if row is None:
        raise ValueError('slot_not_found')

    defaults = {slot['slotKey']: slot for slot in DEFAULT_AD_SLOTS}
    base_config = defaults[slot_key]['config'].copy()
    if row.config_json:
        try:
            base_config.update(json.loads(row.config_json) or {})
        except Exception:
            pass

    previous_config = _normalize_slot_config(base_config, include_reserved=True)
    merged = previous_config.copy()
    merged.update(payload or {})
    variant = (
        'reserved'
        if any(
            key in (payload or {})
            for key in ['reservedTitle', 'reservedMessage', 'reservedCtaLabel', 'reservedTargetUrl', 'reservedImageUrl', 'reservationStartAt', 'reservationEndAt']
        )
        else 'live'
    )
    next_config = _normalize_slot_config(merged, include_reserved=True)
    next_config = _upsert_campaign_history(db, row, previous_config, next_config, variant)

    if 'status' in (payload or {}):
        row.status = str((payload or {}).get('status') or row.status or 'active').strip() or 'active'

    row.config_json = json.dumps(next_config, ensure_ascii=False)
    db.add(row)
    db.commit()
    db.refresh(row)
    return _serialize_slot(row, defaults[slot_key])


def list_ad_campaigns(
    db: OrmSession,
    slot_key: Optional[str] = None,
    limit: int = 100,
    *,
    query: Optional[str] = None,
    variant: Optional[str] = None,
    status: Optional[str] = None,
    period_from: Optional[str] = None,
    period_to: Optional[str] = None,
) -> List[Dict[str, Any]]:
    ensure_default_ad_slots(db)

    slot_query = select(AdSlot)
    if slot_key:
        slot_query = slot_query.where(AdSlot.slot_key == slot_key)
    slots = db.scalars(slot_query).all()
    if not slots:
        return []

    slot_ids = [slot.id for slot in slots]
    slot_key_map = {slot.id: slot.slot_key for slot in slots}

    campaign_query = select(AdCampaign).where(AdCampaign.slot_id.in_(slot_ids)).order_by(AdCampaign.created_at.desc())
    campaigns = [
        campaign
        for campaign in db.scalars(campaign_query).all()
        if _campaign_matches_filters(
            campaign,
            query=query,
            variant=variant,
            status=status,
            period_from=period_from,
            period_to=period_to,
        )
    ][:limit]
    if not campaigns:
        return []

    campaign_ids = [campaign.id for campaign in campaigns]

    impression_rows = db.execute(
        select(AdImpression.campaign_id, func.count(AdImpression.id))
        .where(AdImpression.campaign_id.in_(campaign_ids))
        .group_by(AdImpression.campaign_id)
    ).all()
    impression_map = {campaign_id: count for campaign_id, count in impression_rows}

    click_rows = db.execute(
        select(AdImpression.campaign_id, func.count(AdClick.id))
        .join(AdClick, AdClick.impression_id == AdImpression.id)
        .where(AdImpression.campaign_id.in_(campaign_ids))
        .group_by(AdImpression.campaign_id)
    ).all()
    click_map = {campaign_id: count for campaign_id, count in click_rows}

    result = []
    for campaign in campaigns:
        impressions = int(impression_map.get(campaign.id, 0) or 0)
        clicks = int(click_map.get(campaign.id, 0) or 0)
        ctr = 0.0 if impressions == 0 else round(clicks / impressions, 4)
        result.append(
            {
                'id': campaign.id,
                'slotKey': slot_key_map.get(campaign.slot_id),
                'variant': campaign.variant,
                'status': campaign.status,
                'title': campaign.title,
                'message': campaign.message,
                'ctaLabel': campaign.cta_label,
                'targetUrl': campaign.target_url,
                'imageUrl': campaign.image_url,
                'startAt': campaign.start_at.isoformat() if campaign.start_at else None,
                'endAt': campaign.end_at.isoformat() if campaign.end_at else None,
                'impressions': impressions,
                'clicks': clicks,
                'ctr': ctr,
                'createdAt': campaign.created_at.isoformat() if campaign.created_at else None,
                'updatedAt': campaign.updated_at.isoformat() if campaign.updated_at else None,
            }
        )
    return result


def record_ad_impression(
    db: OrmSession,
    *,
    slot_key: str,
    campaign_id: str,
    screen_name: Optional[str] = None,
    user_id: Optional[str] = None,
    session_id: Optional[str] = None,
    creative_id: Optional[str] = None,
) -> Dict[str, Any]:
    ensure_default_ad_slots(db)
    slot = db.scalar(select(AdSlot).where(AdSlot.slot_key == slot_key))
    if slot is None:
        raise ValueError('slot_not_found')

    campaign = db.get(AdCampaign, campaign_id)
    if campaign is None or campaign.slot_id != slot.id:
        raise ValueError('campaign_not_found')

    impression = AdImpression(
        slot_id=slot.id,
        user_id=user_id,
        session_id=session_id,
        screen_name=screen_name,
        campaign_id=campaign.id,
        creative_id=creative_id or campaign.id,
    )
    db.add(impression)
    db.commit()
    db.refresh(impression)
    return {
        'impressionId': impression.id,
        'slotKey': slot.slot_key,
        'campaignId': campaign.id,
        'creativeId': impression.creative_id,
        'createdAt': impression.created_at.isoformat() if impression.created_at else None,
    }


def record_ad_click(db: OrmSession, *, impression_id: str) -> Dict[str, Any]:
    impression = db.get(AdImpression, impression_id)
    if impression is None:
        raise ValueError('impression_not_found')

    click = AdClick(impression_id=impression.id)
    db.add(click)
    db.commit()
    db.refresh(click)
    return {
        'clickId': click.id,
        'impressionId': impression.id,
        'campaignId': impression.campaign_id,
        'createdAt': click.created_at.isoformat() if click.created_at else None,
    }


def export_ad_campaign_xlsx(db: OrmSession, campaign_id: str) -> tuple[bytes, str]:
    campaign = db.get(AdCampaign, campaign_id)
    if campaign is None:
        raise ValueError('campaign_not_found')

    slot = db.get(AdSlot, campaign.slot_id)
    if slot is None:
        raise ValueError('slot_not_found')

    impressions = int(db.scalar(select(func.count(AdImpression.id)).where(AdImpression.campaign_id == campaign.id)) or 0)
    clicks = int(
        db.scalar(
            select(func.count(AdClick.id))
            .join(AdImpression, AdImpression.id == AdClick.impression_id)
            .where(AdImpression.campaign_id == campaign.id)
        )
        or 0
    )
    ctr = 0.0 if impressions == 0 else clicks / impressions

    workbook = Workbook()
    overview = workbook.active
    overview.title = 'Campaign'

    overview['A1'] = 'Cartly Ad Campaign Export'
    overview['A1'].font = Font(bold=True, size=16)

    rows = [
        ('campaign_id', campaign.id),
        ('slot_key', slot.slot_key),
        ('variant', campaign.variant),
        ('status', campaign.status),
        ('title', campaign.title),
        ('message', campaign.message),
        ('cta_label', campaign.cta_label or ''),
        ('target_url', campaign.target_url or ''),
        ('image_url', campaign.image_url or ''),
        ('start_at', campaign.start_at.isoformat() if campaign.start_at else ''),
        ('end_at', campaign.end_at.isoformat() if campaign.end_at else ''),
        ('created_at', campaign.created_at.isoformat() if campaign.created_at else ''),
        ('updated_at', campaign.updated_at.isoformat() if campaign.updated_at else ''),
        ('impressions', impressions),
        ('clicks', clicks),
        ('ctr', round(ctr, 4)),
    ]
    for index, (label, value) in enumerate(rows, start=3):
        overview.cell(row=index, column=1, value=label).font = Font(bold=True)
        overview.cell(row=index, column=2, value=value)

    image_formula_url = _campaign_image_formula_url(campaign.image_url)
    if image_formula_url:
        overview['D3'] = 'image_preview'
        overview['D3'].font = Font(bold=True)
        overview['D4'] = f'=IMAGE("{image_formula_url}")'
        overview['D18'] = 'image_link'
        overview['D18'].font = Font(bold=True)
        overview['D19'] = image_formula_url
        overview.column_dimensions['D'].width = 28
        overview.column_dimensions['E'].width = 28
        overview.row_dimensions[4].height = 180
    else:
        overview['D3'] = 'image_preview'
        overview['D3'].font = Font(bold=True)
        overview['D4'] = '이미지 없음'

    for column in ['A', 'B']:
        overview.column_dimensions[column].width = 24 if column == 'A' else 42

    detail = workbook.create_sheet('Metrics')
    detail.append(['metric', 'value'])
    detail['A1'].font = Font(bold=True)
    detail['B1'].font = Font(bold=True)
    detail.append(['slot_key', slot.slot_key])
    detail.append(['campaign_id', campaign.id])
    detail.append(['variant', campaign.variant])
    detail.append(['status', campaign.status])
    detail.append(['impressions', impressions])
    detail.append(['clicks', clicks])
    detail.append(['ctr', round(ctr, 4)])
    detail.column_dimensions['A'].width = 22
    detail.column_dimensions['B'].width = 32

    output = io.BytesIO()
    workbook.save(output)
    filename = _safe_xlsx_filename(f'{slot.slot_key}-{campaign.variant}-{campaign.title or campaign.id}') + '.xlsx'
    return output.getvalue(), filename


def export_ad_campaigns_xlsx(
    db: OrmSession,
    *,
    slot_key: Optional[str] = None,
    query: Optional[str] = None,
    variant: Optional[str] = None,
    status: Optional[str] = None,
    period_from: Optional[str] = None,
    period_to: Optional[str] = None,
    limit: int = 500,
) -> tuple[bytes, str]:
    campaigns = list_ad_campaigns(
        db,
        slot_key=slot_key,
        limit=limit,
        query=query,
        variant=variant,
        status=status,
        period_from=period_from,
        period_to=period_to,
    )

    workbook = Workbook()
    overview = workbook.active
    overview.title = 'Overview'
    overview['A1'] = 'Cartly Past Ad Campaign Export'
    overview['A1'].font = Font(bold=True, size=16)

    overview_rows = [
        ('query', query or '-'),
        ('variant', variant or 'all'),
        ('status', status or 'all'),
        ('period_from', period_from or '-'),
        ('period_to', period_to or '-'),
        ('total_campaigns', len(campaigns)),
    ]
    for index, (label, value) in enumerate(overview_rows, start=3):
        overview.cell(row=index, column=1, value=label).font = Font(bold=True)
        overview.cell(row=index, column=2, value=value)
    overview.column_dimensions['A'].width = 24
    overview.column_dimensions['B'].width = 32

    headers = [
        'campaign_id',
        'variant',
        'status',
        'title',
        'message',
        'cta_label',
        'target_url',
        'image_url',
        'image_preview',
        'start_at',
        'end_at',
        'impressions',
        'clicks',
        'ctr',
        'created_at',
        'updated_at',
    ]
    slot_query = select(AdSlot)
    if slot_key:
        slot_query = slot_query.where(AdSlot.slot_key == slot_key)
    slot_rows = db.scalars(slot_query).all()
    slot_map = {slot_row.slot_key: slot_row for slot_row in slot_rows}
    default_slot_map = {slot['slotKey']: slot for slot in DEFAULT_AD_SLOTS}

    campaigns_by_slot: Dict[str, List[Dict[str, Any]]] = {}
    for campaign in campaigns:
        campaigns_by_slot.setdefault(campaign.get('slotKey') or 'unknown', []).append(campaign)

    for raw_slot_key, slot_campaigns in campaigns_by_slot.items():
        title = _safe_xlsx_filename(raw_slot_key).replace('-', '_')[:31] or 'slot'
        sheet = workbook.create_sheet(title)

        fallback_slot = default_slot_map.get(raw_slot_key)
        slot_config: Dict[str, Any] = fallback_slot['config'].copy() if fallback_slot else {}
        slot_row = slot_map.get(raw_slot_key)
        if slot_row and slot_row.config_json:
            try:
                slot_config.update(json.loads(slot_row.config_json) or {})
            except Exception:
                pass
        slot_config = _normalize_slot_config(slot_config, include_reserved=True)

        meta_rows = [
            ('slot_key', raw_slot_key),
            ('slot_name', slot_config.get('slotLabel') or raw_slot_key),
            ('slot_description', slot_config.get('slotDescription') or '-'),
            ('placement_type', slot_row.placement_type if slot_row else fallback_slot['placementType'] if fallback_slot else '-'),
            ('screen', slot_config.get('screen') or '-'),
            ('position', slot_config.get('position') or '-'),
            ('placement_note', slot_config.get('placementNote') or '-'),
            ('total_campaigns', len(slot_campaigns)),
        ]
        for index, (label, value) in enumerate(meta_rows, start=1):
            sheet.cell(row=index, column=1, value=label).font = Font(bold=True)
            sheet.cell(row=index, column=2, value=value)

        table_start_row = len(meta_rows) + 3
        for col_index, header in enumerate(headers, start=1):
            sheet.cell(row=table_start_row, column=col_index, value=header).font = Font(bold=True)

        for row_offset, campaign in enumerate(slot_campaigns, start=1):
            image_url = _campaign_image_formula_url(campaign.get('imageUrl'))
            values = [
                campaign.get('id'),
                campaign.get('variant'),
                campaign.get('status'),
                campaign.get('title'),
                campaign.get('message'),
                campaign.get('ctaLabel'),
                campaign.get('targetUrl'),
                campaign.get('imageUrl'),
                f'=IMAGE("{image_url}")' if image_url else '',
                campaign.get('startAt'),
                campaign.get('endAt'),
                campaign.get('impressions'),
                campaign.get('clicks'),
                campaign.get('ctr'),
                campaign.get('createdAt'),
                campaign.get('updatedAt'),
            ]
            for col_index, value in enumerate(values, start=1):
                sheet.cell(row=table_start_row + row_offset, column=col_index, value=value)

        sheet.freeze_panes = f'A{table_start_row + 1}'
        for column in sheet.columns:
            max_length = max(len(str(cell.value or '')) for cell in column)
            sheet.column_dimensions[column[0].column_letter].width = min(max(max_length + 2, 12), 36)

    output = io.BytesIO()
    workbook.save(output)
    suffix = f'{period_from or "all"}_{period_to or "all"}'
    filename = _safe_xlsx_filename(f'wimc-ad-campaigns-{suffix}') + '.xlsx'
    return output.getvalue(), filename


def app_ad_slots_config(db: OrmSession, ads_enabled: bool) -> List[Dict[str, Any]]:
    slots = list_ad_slots(db)
    result = []
    for slot in slots:
        result.append(
            {
                'slotKey': slot['slotKey'],
                'placementType': slot['placementType'],
                'enabled': ads_enabled and slot['status'] == 'active',
                'config': {
                    **_normalize_slot_config(slot['config']),
                    'campaignId': slot['config'].get('liveCampaignId'),
                },
            }
        )
    return result
