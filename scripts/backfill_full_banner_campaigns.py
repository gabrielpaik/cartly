#!/usr/bin/env python3
import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = ROOT / 'backend'
sys.path.insert(0, str(BACKEND_ROOT))

from sqlalchemy import select  # noqa: E402

from app.db.models import AdCampaign, AdSlot  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402

FULL_BANNER_PLACEMENTS = {'inline', 'bottom_sheet', 'floating_overlay'}


def _load_params(raw: Optional[str]) -> Dict[str, Any]:
    if not raw:
        return {}
    parsed = json.loads(raw)
    if not isinstance(parsed, dict):
        raise ValueError(f'landing_params_json must decode to an object, got {type(parsed).__name__}')
    return parsed


def main() -> int:
    parser = argparse.ArgumentParser(
        description='Backfill legacy Cartly ad campaigns so banner-capable placements persist renderStyle=full_banner.'
    )
    parser.add_argument('--apply', action='store_true', help='Persist updates. Without this flag the script only reports.')
    args = parser.parse_args()

    with SessionLocal() as db:
        campaigns = db.execute(
            select(AdCampaign, AdSlot)
            .join(AdSlot, AdCampaign.slot_id == AdSlot.id)
            .order_by(AdSlot.slot_key.asc(), AdCampaign.created_at.asc())
        ).all()

        examined = 0
        updated = 0
        skipped = 0
        slot_counts: Counter[str] = Counter()
        dirty_rows: List[Tuple[str, str, str]] = []

        for campaign, slot in campaigns:
            examined += 1
            placement = str(slot.placement_type or '').strip()
            if placement not in FULL_BANNER_PLACEMENTS:
                skipped += 1
                continue

            params = _load_params(campaign.landing_params_json)
            current_style = str(params.get('renderStyle') or '').strip()
            if current_style == 'full_banner':
                skipped += 1
                continue

            params['renderStyle'] = 'full_banner'
            campaign.landing_params_json = json.dumps(params, ensure_ascii=False)
            updated += 1
            slot_counts[slot.slot_key] += 1
            dirty_rows.append((campaign.id, slot.slot_key, campaign.title or ''))

        if args.apply and updated:
            db.commit()
        else:
            db.rollback()

    mode = 'APPLIED' if args.apply else 'DRY_RUN'
    print(f'mode={mode}')
    print(f'examined={examined}')
    print(f'updated={updated}')
    print(f'skipped={skipped}')
    if slot_counts:
        print('updated_by_slot=')
        for slot_key, count in sorted(slot_counts.items()):
            print(f'  - {slot_key}: {count}')
    if dirty_rows:
        print('updated_rows=')
        for campaign_id, slot_key, title in dirty_rows:
            print(f'  - {campaign_id} | {slot_key} | {title}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
