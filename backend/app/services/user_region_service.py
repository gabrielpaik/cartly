from __future__ import annotations

import uuid
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Dict, Iterable, List, Optional, Sequence

from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session as OrmSession

from ..db.models import User, UserRegionEvent, UserRegionProfile

REGION_SEGMENT_MODES = {'none', 'recent', 'frequent', 'primary'}


def _clean_region_string(value: Optional[str]) -> Optional[str]:
    trimmed = (value or '').strip()
    return trimmed or None


def _normalize_timestamp(value: Optional[datetime]) -> datetime:
    if value is None:
        return datetime.utcnow()
    if value.tzinfo is not None:
        return value.astimezone().replace(tzinfo=None)
    return value


def resolve_region_label(city: Optional[str], district: Optional[str], neighborhood: Optional[str]) -> Optional[str]:
    parts = [part for part in [_clean_region_string(neighborhood), _clean_region_string(district), _clean_region_string(city)] if part]
    return ', '.join(parts) if parts else None


def build_region_key(city: Optional[str], district: Optional[str], neighborhood: Optional[str]) -> Optional[str]:
    next_city = _clean_region_string(city)
    next_district = _clean_region_string(district)
    next_neighborhood = _clean_region_string(neighborhood)
    if next_city and next_district and next_neighborhood:
        return f'neighborhood:{next_city}/{next_district}/{next_neighborhood}'
    if next_city and next_district:
        return f'district:{next_city}/{next_district}'
    if next_city:
        return f'city:{next_city}'
    return None


def parse_region_key(key: Optional[str]) -> Optional[tuple[str, Optional[str], Optional[str], Optional[str]]]:
    raw = (key or '').strip()
    if not raw or ':' not in raw:
        return None
    level, payload = raw.split(':', 1)
    level = level.strip().lower()
    if level not in {'city', 'district', 'neighborhood'}:
        return None
    parts = [part.strip() or None for part in payload.split('/')]
    city = parts[0] if len(parts) > 0 else None
    district = parts[1] if len(parts) > 1 else None
    neighborhood = parts[2] if len(parts) > 2 else None
    return level, city, district, neighborhood


def normalize_region_keys(keys: Optional[Sequence[str]]) -> List[str]:
    normalized = []
    seen = set()
    for key in keys or []:
        parsed = parse_region_key(key)
        if not parsed:
            continue
        level, city, district, neighborhood = parsed
        canonical = build_region_key(city, district if level in {'district', 'neighborhood'} else None, neighborhood if level == 'neighborhood' else None)
        if not canonical or canonical in seen:
            continue
        seen.add(canonical)
        normalized.append(canonical)
    return sorted(normalized)


def _region_level_from_key(key: Optional[str]) -> str:
    parsed = parse_region_key(key)
    return parsed[0] if parsed else 'all'


def _day_bounds(value: datetime) -> tuple[datetime, datetime]:
    start = datetime(value.year, value.month, value.day)
    return start, start + timedelta(days=1)


def sync_user_region_context(
    db: OrmSession,
    user: Optional[User],
    *,
    city: Optional[str] = None,
    district: Optional[str] = None,
    neighborhood: Optional[str] = None,
    captured_at: Optional[datetime] = None,
    source: Optional[str] = None,
) -> None:
    if user is None:
        return

    next_city = _clean_region_string(city)
    next_district = _clean_region_string(district)
    next_neighborhood = _clean_region_string(neighborhood)
    if not any([next_city, next_district, next_neighborhood]):
        return

    next_captured_at = _normalize_timestamp(captured_at)
    region_label = resolve_region_label(next_city, next_district, next_neighborhood)
    region_key = build_region_key(next_city, next_district, next_neighborhood)
    normalized_source = (_clean_region_string(source) or 'runtime').lower()

    user.last_region_city = next_city
    user.last_region_district = next_district
    user.last_region_neighborhood = next_neighborhood
    user.last_region_label = region_label
    user.last_region_captured_at = next_captured_at
    db.add(user)

    if not region_key:
        return

    latest = db.scalar(
        select(UserRegionEvent)
        .where(UserRegionEvent.user_id == user.id)
        .order_by(UserRegionEvent.captured_at.desc(), UserRegionEvent.created_at.desc())
        .limit(1)
    )
    if latest is not None:
        same_region = latest.region_key == region_key
        same_source = (latest.source or 'runtime') == normalized_source
        diff_seconds = abs((next_captured_at - latest.captured_at).total_seconds()) if latest.captured_at else None
        if same_region and same_source and diff_seconds is not None and diff_seconds < 3600:
            return

    day_start, day_end = _day_bounds(next_captured_at)
    already_seen_today = db.scalar(
        select(func.count(UserRegionEvent.id))
        .where(
            UserRegionEvent.user_id == user.id,
            UserRegionEvent.region_key == region_key,
            UserRegionEvent.captured_at >= day_start,
            UserRegionEvent.captured_at < day_end,
        )
    ) or 0

    event = UserRegionEvent(
        id=str(uuid.uuid4()),
        user_id=user.id,
        source=normalized_source,
        city=next_city,
        district=next_district,
        neighborhood=next_neighborhood,
        region_label=region_label,
        region_key=region_key,
        captured_at=next_captured_at,
    )
    db.add(event)

    profile = db.scalar(
        select(UserRegionProfile).where(
            UserRegionProfile.user_id == user.id,
            UserRegionProfile.region_key == region_key,
        )
    )
    if profile is None:
        profile = UserRegionProfile(
            id=str(uuid.uuid4()),
            user_id=user.id,
            region_level=_region_level_from_key(region_key),
            city=next_city,
            district=next_district,
            neighborhood=next_neighborhood,
            region_label=region_label,
            region_key=region_key,
            visit_count=0,
            active_day_count=0,
            weekday_visit_count=0,
            weekend_visit_count=0,
            first_seen_at=next_captured_at,
            last_seen_at=next_captured_at,
            last_source=normalized_source,
        )

    profile.region_level = _region_level_from_key(region_key)
    profile.city = next_city
    profile.district = next_district
    profile.neighborhood = next_neighborhood
    profile.region_label = region_label
    profile.region_key = region_key
    profile.visit_count = int(profile.visit_count or 0) + 1
    profile.first_seen_at = min(profile.first_seen_at or next_captured_at, next_captured_at)
    profile.last_seen_at = max(profile.last_seen_at or next_captured_at, next_captured_at)
    profile.last_source = normalized_source
    if already_seen_today == 0:
        profile.active_day_count = int(profile.active_day_count or 0) + 1
    if next_captured_at.weekday() >= 5:
        profile.weekend_visit_count = int(profile.weekend_visit_count or 0) + 1
    else:
        profile.weekday_visit_count = int(profile.weekday_visit_count or 0) + 1
    db.add(profile)


def list_user_region_profiles(db: OrmSession, user_id: str, *, limit: int = 12) -> List[dict]:
    rows = list(
        db.scalars(
            select(UserRegionProfile)
            .where(UserRegionProfile.user_id == user_id)
            .order_by(UserRegionProfile.visit_count.desc(), UserRegionProfile.last_seen_at.desc(), UserRegionProfile.region_label.asc())
            .limit(max(1, min(limit, 100)))
        ).all()
    )
    return [serialize_region_profile(row) for row in rows]


def list_user_region_events(db: OrmSession, user_id: str, *, limit: int = 20) -> List[dict]:
    rows = list(
        db.scalars(
            select(UserRegionEvent)
            .where(UserRegionEvent.user_id == user_id)
            .order_by(UserRegionEvent.captured_at.desc(), UserRegionEvent.created_at.desc())
            .limit(max(1, min(limit, 100)))
        ).all()
    )
    return [serialize_region_event(row) for row in rows]


def serialize_region_profile(row: UserRegionProfile) -> dict:
    return {
        'regionKey': row.region_key,
        'regionLevel': row.region_level,
        'city': row.city,
        'district': row.district,
        'neighborhood': row.neighborhood,
        'label': row.region_label,
        'visitCount': int(row.visit_count or 0),
        'activeDayCount': int(row.active_day_count or 0),
        'weekdayVisitCount': int(row.weekday_visit_count or 0),
        'weekendVisitCount': int(row.weekend_visit_count or 0),
        'firstSeenAt': row.first_seen_at.isoformat() if row.first_seen_at else None,
        'lastSeenAt': row.last_seen_at.isoformat() if row.last_seen_at else None,
        'lastSource': row.last_source,
    }


def serialize_region_event(row: UserRegionEvent) -> dict:
    return {
        'id': row.id,
        'source': row.source,
        'regionKey': row.region_key,
        'city': row.city,
        'district': row.district,
        'neighborhood': row.neighborhood,
        'label': row.region_label,
        'capturedAt': row.captured_at.isoformat() if row.captured_at else None,
        'createdAt': row.created_at.isoformat() if row.created_at else None,
    }


def build_user_region_summary_map(db: OrmSession, user_ids: Sequence[str], *, recent_days: int = 30) -> Dict[str, dict]:
    normalized_user_ids = [user_id for user_id in user_ids if str(user_id or '').strip()]
    if not normalized_user_ids:
        return {}

    profile_rows = list(
        db.scalars(
            select(UserRegionProfile)
            .where(UserRegionProfile.user_id.in_(normalized_user_ids))
            .order_by(UserRegionProfile.user_id.asc(), UserRegionProfile.visit_count.desc(), UserRegionProfile.last_seen_at.desc(), UserRegionProfile.region_label.asc())
        ).all()
    )
    profiles_by_user: Dict[str, List[UserRegionProfile]] = defaultdict(list)
    for row in profile_rows:
        profiles_by_user[row.user_id].append(row)

    since = datetime.utcnow() - timedelta(days=max(1, recent_days))
    recent_rows = list(
        db.execute(
            select(UserRegionEvent.user_id, UserRegionEvent.region_key)
            .where(UserRegionEvent.user_id.in_(normalized_user_ids), UserRegionEvent.captured_at >= since)
            .group_by(UserRegionEvent.user_id, UserRegionEvent.region_key)
        ).all()
    )
    recent_regions_by_user: Dict[str, List[str]] = defaultdict(list)
    for user_id, region_key in recent_rows:
        recent_regions_by_user[user_id].append(region_key)

    summary: Dict[str, dict] = {}
    for user_id in normalized_user_ids:
        profiles = profiles_by_user.get(user_id, [])
        labels = [row.region_label for row in profiles if (row.region_label or '').strip()]
        top_labels = labels[:3]
        primary = profiles[0] if profiles else None
        summary[user_id] = {
            'regionActivityCount': len(profiles),
            'recentRegionCount30d': len(recent_regions_by_user.get(user_id, [])),
            'primaryRegionKey': primary.region_key if primary else None,
            'primaryRegionLabel': primary.region_label if primary else None,
            'topRegionLabels': top_labels,
            'topRegionSummary': _summarize_labels(top_labels, len(labels)),
        }
    return summary


def _summarize_labels(labels: Sequence[str], total_count: int) -> Optional[str]:
    clean = [label.strip() for label in labels if label and label.strip()]
    if not clean:
        return None
    if total_count <= 1:
        return clean[0]
    return f'{clean[0]} 외 {max(0, total_count - 1)}'


def resolve_user_ids_for_region_segment(
    db: OrmSession,
    *,
    mode: str,
    region_keys: Optional[Sequence[str]] = None,
    recent_within_days: Optional[int] = None,
    min_visits: Optional[int] = None,
    candidate_user_ids: Optional[Iterable[str]] = None,
) -> Optional[set[str]]:
    normalized_mode = (mode or 'none').strip().lower()
    if normalized_mode not in REGION_SEGMENT_MODES or normalized_mode == 'none':
        return None
    keys = normalize_region_keys(region_keys)
    if not keys:
        return set()

    candidate_ids = [user_id for user_id in (candidate_user_ids or []) if str(user_id or '').strip()]

    if normalized_mode == 'recent':
        since = datetime.utcnow() - timedelta(days=max(1, recent_within_days or 30))
        stmt = select(UserRegionEvent.user_id).where(
            UserRegionEvent.region_key.in_(keys),
            UserRegionEvent.captured_at >= since,
        )
        if candidate_ids:
            stmt = stmt.where(UserRegionEvent.user_id.in_(candidate_ids))
        rows = db.execute(stmt.group_by(UserRegionEvent.user_id)).all()
        return {row[0] for row in rows if row[0]}

    if normalized_mode == 'frequent':
        threshold = max(1, min_visits or 3)
        stmt = select(UserRegionProfile.user_id).where(
            UserRegionProfile.region_key.in_(keys),
            UserRegionProfile.visit_count >= threshold,
        )
        if candidate_ids:
            stmt = stmt.where(UserRegionProfile.user_id.in_(candidate_ids))
        rows = db.execute(stmt.group_by(UserRegionProfile.user_id)).all()
        return {row[0] for row in rows if row[0]}

    profile_stmt = select(UserRegionProfile)
    if candidate_ids:
        profile_stmt = profile_stmt.where(UserRegionProfile.user_id.in_(candidate_ids))
    rows = list(
        db.scalars(
            profile_stmt.order_by(UserRegionProfile.user_id.asc(), UserRegionProfile.visit_count.desc(), UserRegionProfile.last_seen_at.desc(), UserRegionProfile.region_label.asc())
        ).all()
    )
    primary_by_user: Dict[str, str] = {}
    for row in rows:
        if row.user_id not in primary_by_user:
            primary_by_user[row.user_id] = row.region_key
    return {user_id for user_id, region_key in primary_by_user.items() if region_key in keys}
