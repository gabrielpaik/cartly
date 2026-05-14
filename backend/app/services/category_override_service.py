from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import delete, select
from sqlalchemy.orm import Session as OrmSession

from ..db.models import CategoryOverride
from .scan_category_service import build_manual_category_meta, list_large_category_options

TARGET_TYPE_SCAN_JOB = 'scan_job'
TARGET_TYPE_CART_ITEM = 'cart_item'
OVERRIDE_SOURCE = 'admin-override-v1'


def load_category_overrides(
    db: OrmSession,
    *,
    target_type: str,
    target_ids: list[str],
) -> dict[str, CategoryOverride]:
    clean_ids = sorted({target_id.strip() for target_id in target_ids if isinstance(target_id, str) and target_id.strip()})
    if not clean_ids:
        return {}
    rows = db.scalars(
        select(CategoryOverride).where(
            CategoryOverride.target_type == target_type,
            CategoryOverride.target_id.in_(clean_ids),
        )
    ).all()
    return {row.target_id: row for row in rows}


def apply_category_override(
    db: OrmSession,
    *,
    target_type: str,
    target_ids: list[str],
    category: Optional[str],
) -> int:
    clean_ids = sorted({target_id.strip() for target_id in target_ids if isinstance(target_id, str) and target_id.strip()})
    if not clean_ids:
        return 0

    trimmed_category = (category or '').strip() or None
    allowed = set(list_large_category_options())
    if trimmed_category is not None and trimmed_category not in allowed:
        raise ValueError('지원하지 않는 카테고리야')

    if trimmed_category is None:
        db.execute(
            delete(CategoryOverride).where(
                CategoryOverride.target_type == target_type,
                CategoryOverride.target_id.in_(clean_ids),
            )
        )
        db.commit()
        return len(clean_ids)

    existing_by_id = load_category_overrides(db, target_type=target_type, target_ids=clean_ids)
    meta = build_manual_category_meta(trimmed_category)
    now = datetime.utcnow()

    for target_id in clean_ids:
        existing = existing_by_id.get(target_id)
        if existing is None:
            db.add(
                CategoryOverride(
                    target_type=target_type,
                    target_id=target_id,
                    naver_large_category=meta['naverLargeCategory'] or trimmed_category,
                    naver_category_path=meta['naverCategoryPath'] or trimmed_category,
                    source=meta['categorySource'] or OVERRIDE_SOURCE,
                    created_at=now,
                    updated_at=now,
                )
            )
            continue
        existing.naver_large_category = meta['naverLargeCategory'] or trimmed_category
        existing.naver_category_path = meta['naverCategoryPath'] or trimmed_category
        existing.source = meta['categorySource'] or OVERRIDE_SOURCE
        existing.updated_at = now
        db.add(existing)

    db.commit()
    return len(clean_ids)


def override_to_category_meta(override: Optional[CategoryOverride]) -> Optional[dict[str, Optional[str]]]:
    if override is None:
        return None
    return {
        'naverLargeCategory': override.naver_large_category,
        'naverCategoryPath': override.naver_category_path,
        'categorySource': override.source or OVERRIDE_SOURCE,
    }
