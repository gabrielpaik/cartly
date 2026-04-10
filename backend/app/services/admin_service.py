from datetime import date, datetime, time, timedelta, timezone
from typing import Optional
from zoneinfo import ZoneInfo

from sqlalchemy import desc, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session as OrmSession

from ..db.models import AdClick, AdImpression, AdSlot, AdminDashboardSnapshot, AppEvent, Cart, ScanJob, User

KST = ZoneInfo('Asia/Seoul')
DASHBOARD_SNAPSHOT_HOUR_KST = 0
VALID_PERIODS = {'week', 'month', 'quarter', 'year'}


def _dashboard_snapshot_time_kst() -> time:
    return time(hour=DASHBOARD_SNAPSHOT_HOUR_KST, minute=0)


def current_snapshot_date_kst(now: Optional[datetime] = None) -> date:
    now_kst = now.astimezone(KST) if now else datetime.now(KST)
    return now_kst.date()


def seconds_until_next_dashboard_snapshot(now: Optional[datetime] = None) -> float:
    now_kst = now.astimezone(KST) if now else datetime.now(KST)
    next_run = now_kst.replace(hour=DASHBOARD_SNAPSHOT_HOUR_KST, minute=0, second=0, microsecond=0)
    if now_kst >= next_run:
        next_run += timedelta(days=1)
    return max((next_run - now_kst).total_seconds(), 1.0)


def _period_start_kst(period: str, now_kst: datetime) -> datetime:
    base = now_kst.replace(hour=0, minute=0, second=0, microsecond=0)
    if period == 'week':
        return base - timedelta(days=base.weekday())
    if period == 'month':
        return base.replace(day=1)
    if period == 'quarter':
        quarter_month = ((base.month - 1) // 3) * 3 + 1
        return base.replace(month=quarter_month, day=1)
    if period == 'year':
        return base.replace(month=1, day=1)
    raise ValueError(f'unsupported period: {period}')


def _to_naive_utc(value: datetime) -> datetime:
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def _top_members_by_saved_carts(
    db: OrmSession,
    *,
    start_utc: Optional[datetime] = None,
    end_utc: Optional[datetime] = None,
    limit: int = 5,
) -> list[dict]:
    stmt = (
        select(
            User.id,
            User.display_name,
            User.email,
            func.count(Cart.id).label('cart_count'),
            func.coalesce(func.sum(Cart.total_price_cached), 0).label('total_value'),
            func.max(Cart.created_at).label('last_saved_at'),
        )
        .join(Cart, Cart.user_id == User.id)
        .where(
            User.status == 'active',
            User.is_guest.is_(False),
            Cart.deleted_at.is_(None),
        )
    )

    if start_utc is not None:
        stmt = stmt.where(Cart.created_at >= start_utc)
    if end_utc is not None:
        stmt = stmt.where(Cart.created_at <= end_utc)

    stmt = (
        stmt.group_by(User.id, User.display_name, User.email)
        .order_by(desc('cart_count'), desc('last_saved_at'))
        .limit(limit)
    )

    return [
        {
            'userId': row[0],
            'displayName': row[1],
            'email': row[2],
            'cartCount': int(row[3] or 0),
            'totalValue': int(row[4] or 0),
            'lastSavedAt': row[5].isoformat() if row[5] else None,
        }
        for row in db.execute(stmt).all()
    ]


def _lifecycle_summary(
    db: OrmSession,
    *,
    start_utc: Optional[datetime] = None,
    end_utc: Optional[datetime] = None,
    active_only: bool = False,
) -> dict:
    def apply_range(stmt, column):
        if start_utc is not None:
            stmt = stmt.where(column >= start_utc)
        if end_utc is not None:
            stmt = stmt.where(column <= end_utc)
        return stmt

    guest_base = select(func.count(User.id)).where(User.auth_provider == 'guest')
    conversion_base = select(func.count(User.id)).where(User.merged_into_user_id.is_not(None), User.merged_at.is_not(None))
    tracked_guest_base = select(func.count(User.id)).where(User.is_guest.is_(True), User.guest_key.is_not(None))
    legacy_guest_base = select(func.count(User.id)).where(User.is_guest.is_(True), User.guest_key.is_(None))
    active_member_base = select(func.count(User.id)).where(User.is_guest.is_(False))

    if active_only:
        guest_base = guest_base.where(User.status == 'active')
        tracked_guest_base = tracked_guest_base.where(User.status == 'active')
        legacy_guest_base = legacy_guest_base.where(User.status == 'active')
        active_member_base = active_member_base.where(User.status == 'active')

    if start_utc is not None or end_utc is not None:
        guest_base = apply_range(guest_base, User.created_at)
        tracked_guest_base = apply_range(tracked_guest_base, User.created_at)
        legacy_guest_base = apply_range(legacy_guest_base, User.created_at)
        active_member_base = apply_range(active_member_base, User.created_at)
        conversion_base = apply_range(conversion_base, User.merged_at)

    guest_profiles = db.scalar(guest_base) or 0
    guest_to_member_conversions = db.scalar(conversion_base) or 0
    tracked_guests = db.scalar(tracked_guest_base) or 0
    legacy_guests = db.scalar(legacy_guest_base) or 0
    active_members = db.scalar(active_member_base) or 0

    legacy_with_carts_stmt = (
        select(func.count(func.distinct(User.id)))
        .join(Cart, Cart.user_id == User.id)
        .where(
            User.status == 'active',
            User.is_guest.is_(True),
            User.guest_key.is_(None),
            Cart.deleted_at.is_(None),
        )
    )
    if start_utc is not None:
        legacy_with_carts_stmt = legacy_with_carts_stmt.where(Cart.created_at >= start_utc)
    if end_utc is not None:
        legacy_with_carts_stmt = legacy_with_carts_stmt.where(Cart.created_at <= end_utc)
    legacy_guests_with_carts = db.scalar(legacy_with_carts_stmt) or 0

    member_users_with_saved_carts_stmt = (
        select(func.count(func.distinct(User.id)))
        .join(Cart, Cart.user_id == User.id)
        .where(
            User.status == 'active',
            User.is_guest.is_(False),
            Cart.deleted_at.is_(None),
        )
    )
    member_saved_carts_stmt = (
        select(func.count(Cart.id))
        .join(User, Cart.user_id == User.id)
        .where(
            User.status == 'active',
            User.is_guest.is_(False),
            Cart.deleted_at.is_(None),
        )
    )

    if start_utc is not None:
        member_users_with_saved_carts_stmt = member_users_with_saved_carts_stmt.where(Cart.created_at >= start_utc)
        member_saved_carts_stmt = member_saved_carts_stmt.where(Cart.created_at >= start_utc)
    if end_utc is not None:
        member_users_with_saved_carts_stmt = member_users_with_saved_carts_stmt.where(Cart.created_at <= end_utc)
        member_saved_carts_stmt = member_saved_carts_stmt.where(Cart.created_at <= end_utc)

    member_users_with_saved_carts = db.scalar(member_users_with_saved_carts_stmt) or 0
    member_saved_carts = db.scalar(member_saved_carts_stmt) or 0
    avg_saved_carts_per_member = (
        round(member_saved_carts / member_users_with_saved_carts, 2)
        if member_users_with_saved_carts
        else 0.0
    )

    conversion_rate = (
        round(guest_to_member_conversions / max(guest_profiles, 1), 4)
        if guest_profiles
        else 0.0
    )

    return {
        'guestProfiles': int(guest_profiles),
        'trackedGuests': int(tracked_guests),
        'legacyGuests': int(legacy_guests),
        'legacyGuestsWithCarts': int(legacy_guests_with_carts),
        'activeMembers': int(active_members),
        'memberUsersWithSavedCarts': int(member_users_with_saved_carts),
        'memberSavedCarts': int(member_saved_carts),
        'avgSavedCartsPerMember': avg_saved_carts_per_member,
        'guestToMemberConversions': int(guest_to_member_conversions),
        'guestToMemberConversionRate': conversion_rate,
        'topMembers': _top_members_by_saved_carts(db, start_utc=start_utc, end_utc=end_utc),
    }


def _live_dashboard_summary(db: OrmSession):
    now = datetime.utcnow()
    day_cut = now - timedelta(days=1)
    week_cut = now - timedelta(days=7)
    month_cut = now - timedelta(days=30)

    dau = db.scalar(select(func.count(func.distinct(AppEvent.user_id))).where(AppEvent.created_at >= day_cut)) or 0
    wau = db.scalar(select(func.count(func.distinct(AppEvent.user_id))).where(AppEvent.created_at >= week_cut)) or 0
    mau = db.scalar(select(func.count(func.distinct(AppEvent.user_id))).where(AppEvent.created_at >= month_cut)) or 0
    active_users = mau
    new_users = db.scalar(select(func.count(User.id)).where(User.created_at >= month_cut)) or 0

    guest_count = db.scalar(select(func.count(User.id)).where(User.is_guest.is_(True), User.status == 'active')) or 0
    member_count = db.scalar(select(func.count(User.id)).where(User.is_guest.is_(False), User.status == 'active')) or 0
    conversion = 0.0 if guest_count == 0 else round(member_count / max(guest_count + member_count, 1), 4)

    total_scans = db.scalar(select(func.count(ScanJob.id))) or 0
    successful_scans = db.scalar(select(func.count(ScanJob.id)).where(ScanJob.status == 'done')) or 0
    scan_success_rate = 0.0 if total_scans == 0 else round(successful_scans / total_scans, 4)

    cart_saved = db.scalar(select(func.count(AppEvent.id)).where(AppEvent.event_name == 'cart_saved')) or 0
    cart_save_rate = 0.0 if total_scans == 0 else round(cart_saved / total_scans, 4)

    ad_impressions = db.scalar(select(func.count(AdImpression.id))) or 0
    ad_clicks = db.scalar(select(func.count(AdClick.id))) or 0
    ad_ctr = 0.0 if ad_impressions == 0 else round(ad_clicks / ad_impressions, 4)

    return {
        'dau': dau,
        'wau': wau,
        'mau': mau,
        'activeUsers': active_users,
        'newUsers': new_users,
        'guestToMemberConversion': conversion,
        'totalScans': total_scans,
        'scanSuccessRate': scan_success_rate,
        'cartSaveRate': cart_save_rate,
        'adImpressions': ad_impressions,
        'adClicks': ad_clicks,
        'adCtr': ad_ctr,
    }


def _apply_snapshot(summary: dict, snapshot: AdminDashboardSnapshot, source: str) -> AdminDashboardSnapshot:
    snapshot.source = source
    snapshot.dau = summary['dau']
    snapshot.wau = summary['wau']
    snapshot.mau = summary['mau']
    snapshot.active_users = summary['activeUsers']
    snapshot.new_users = summary['newUsers']
    snapshot.guest_to_member_conversion = summary['guestToMemberConversion']
    snapshot.total_scans = summary['totalScans']
    snapshot.scan_success_rate = summary['scanSuccessRate']
    snapshot.cart_save_rate = summary['cartSaveRate']
    snapshot.ad_impressions = summary['adImpressions']
    snapshot.ad_clicks = summary['adClicks']
    snapshot.ad_ctr = summary['adCtr']
    return snapshot


def _serialize_snapshot(snapshot: AdminDashboardSnapshot) -> dict:
    return {
        'dau': snapshot.dau,
        'wau': snapshot.wau,
        'mau': snapshot.mau,
        'activeUsers': snapshot.active_users,
        'newUsers': snapshot.new_users,
        'guestToMemberConversion': snapshot.guest_to_member_conversion,
        'totalScans': snapshot.total_scans,
        'scanSuccessRate': snapshot.scan_success_rate,
        'cartSaveRate': snapshot.cart_save_rate,
        'adImpressions': snapshot.ad_impressions,
        'adClicks': snapshot.ad_clicks,
        'adCtr': snapshot.ad_ctr,
        'snapshotDate': snapshot.snapshot_date.isoformat(),
        'snapshotGeneratedAt': snapshot.updated_at.isoformat() if snapshot.updated_at else None,
        'snapshotSource': snapshot.source,
        'dataMode': 'snapshot',
    }


def dashboard_period_summary(db: OrmSession, period: str, now: Optional[datetime] = None) -> dict:
    if period not in VALID_PERIODS:
        raise ValueError(f'unsupported period: {period}')

    now_kst = now.astimezone(KST) if now else datetime.now(KST)
    start_kst = _period_start_kst(period, now_kst)
    start_utc = _to_naive_utc(start_kst)
    end_utc = _to_naive_utc(now_kst)

    active_users = db.scalar(
        select(func.count(func.distinct(AppEvent.user_id))).where(AppEvent.created_at >= start_utc, AppEvent.created_at <= end_utc)
    ) or 0

    new_users = db.scalar(select(func.count(User.id)).where(User.created_at >= start_utc, User.created_at <= end_utc)) or 0
    guest_users = db.scalar(
        select(func.count(User.id)).where(User.created_at >= start_utc, User.created_at <= end_utc, User.is_guest.is_(True))
    ) or 0
    member_users = db.scalar(
        select(func.count(User.id)).where(User.created_at >= start_utc, User.created_at <= end_utc, User.is_guest.is_(False))
    ) or 0
    conversion = 0.0 if new_users == 0 else round(member_users / max(new_users, 1), 4)

    total_scans = db.scalar(select(func.count(ScanJob.id)).where(ScanJob.created_at >= start_utc, ScanJob.created_at <= end_utc)) or 0
    successful_scans = db.scalar(
        select(func.count(ScanJob.id)).where(ScanJob.created_at >= start_utc, ScanJob.created_at <= end_utc, ScanJob.status == 'done')
    ) or 0
    scan_success_rate = 0.0 if total_scans == 0 else round(successful_scans / total_scans, 4)

    cart_saves = db.scalar(
        select(func.count(AppEvent.id)).where(AppEvent.created_at >= start_utc, AppEvent.created_at <= end_utc, AppEvent.event_name == 'cart_saved')
    ) or 0
    cart_save_rate = 0.0 if total_scans == 0 else round(cart_saves / total_scans, 4)

    ad_impressions = db.scalar(
        select(func.count(AdImpression.id)).where(AdImpression.created_at >= start_utc, AdImpression.created_at <= end_utc)
    ) or 0
    ad_clicks = db.scalar(
        select(func.count(AdClick.id)).where(AdClick.created_at >= start_utc, AdClick.created_at <= end_utc)
    ) or 0
    ad_ctr = 0.0 if ad_impressions == 0 else round(ad_clicks / ad_impressions, 4)

    impression_rows = db.execute(
        select(AdSlot.slot_key, func.count(AdImpression.id))
        .join(AdImpression, AdImpression.slot_id == AdSlot.id)
        .where(AdImpression.created_at >= start_utc, AdImpression.created_at <= end_utc)
        .group_by(AdSlot.slot_key)
    ).all()
    impression_map = {slot_key: int(count or 0) for slot_key, count in impression_rows}

    click_rows = db.execute(
        select(AdSlot.slot_key, func.count(AdClick.id))
        .join(AdImpression, AdClick.impression_id == AdImpression.id)
        .join(AdSlot, AdImpression.slot_id == AdSlot.id)
        .where(AdClick.created_at >= start_utc, AdClick.created_at <= end_utc)
        .group_by(AdSlot.slot_key)
    ).all()
    click_map = {slot_key: int(count or 0) for slot_key, count in click_rows}

    slot_rows = db.execute(select(AdSlot.slot_key).order_by(AdSlot.created_at.asc())).all()
    ad_slot_rows = []
    for row in slot_rows:
        slot_key = row[0]
        impressions = impression_map.get(slot_key, 0)
        clicks = click_map.get(slot_key, 0)
        ctr = round(clicks / impressions, 4) if impressions else 0.0
        ad_slot_rows.append(
            {
                'slotKey': slot_key,
                'impressions': impressions,
                'clicks': clicks,
                'ctr': ctr,
            }
        )

    return {
        'period': period,
        'rangeStart': start_kst.date().isoformat(),
        'rangeEnd': now_kst.date().isoformat(),
        'activeUsers': active_users,
        'newUsers': new_users,
        'guestUsers': guest_users,
        'memberUsers': member_users,
        'guestToMemberConversion': conversion,
        'totalScans': total_scans,
        'successfulScans': successful_scans,
        'scanSuccessRate': scan_success_rate,
        'cartSaves': cart_saves,
        'cartSaveRate': cart_save_rate,
        'adImpressions': ad_impressions,
        'adClicks': ad_clicks,
        'adCtr': ad_ctr,
        'adSlots': ad_slot_rows,
        'deviceBreakdownReady': True,
        'lifecycle': _lifecycle_summary(db, start_utc=start_utc, end_utc=end_utc),
    }


def refresh_dashboard_summary_snapshot(
    db: OrmSession,
    snapshot_date: Optional[date] = None,
    source: str = 'manual',
) -> dict:
    target_date = snapshot_date or current_snapshot_date_kst()
    summary = _live_dashboard_summary(db)
    snapshot = db.get(AdminDashboardSnapshot, target_date)
    if snapshot is None:
        snapshot = AdminDashboardSnapshot(snapshot_date=target_date)

    _apply_snapshot(summary, snapshot, source)
    db.add(snapshot)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        snapshot = db.get(AdminDashboardSnapshot, target_date) or AdminDashboardSnapshot(snapshot_date=target_date)
        _apply_snapshot(summary, snapshot, source)
        db.add(snapshot)
        db.commit()

    db.refresh(snapshot)
    serialized = _serialize_snapshot(snapshot)
    serialized['lifecycle'] = _lifecycle_summary(db, active_only=True)
    return serialized


def ensure_today_dashboard_snapshot(db: OrmSession) -> Optional[dict]:
    now_kst = datetime.now(KST)
    if now_kst.time() < _dashboard_snapshot_time_kst():
        return None

    snapshot_date = now_kst.date()
    snapshot = db.get(AdminDashboardSnapshot, snapshot_date)
    if snapshot is not None:
        serialized = _serialize_snapshot(snapshot)
        serialized['lifecycle'] = _lifecycle_summary(db, active_only=True)
        return serialized

    return refresh_dashboard_summary_snapshot(db, snapshot_date=snapshot_date, source='scheduled')


def get_latest_dashboard_snapshot(db: OrmSession) -> Optional[dict]:
    stmt = select(AdminDashboardSnapshot).order_by(AdminDashboardSnapshot.snapshot_date.desc())
    snapshot = db.scalars(stmt).first()
    if snapshot is None:
        return None
    serialized = _serialize_snapshot(snapshot)
    serialized['lifecycle'] = _lifecycle_summary(db, active_only=True)
    return serialized


def list_dashboard_snapshots(db: OrmSession, limit: int = 30) -> list[dict]:
    stmt = select(AdminDashboardSnapshot).order_by(AdminDashboardSnapshot.snapshot_date.desc()).limit(limit)
    return [_serialize_snapshot(snapshot) for snapshot in db.scalars(stmt).all()]


def dashboard_summary(db: OrmSession):
    snapshot = get_latest_dashboard_snapshot(db)
    if snapshot is not None:
        return snapshot

    summary = _live_dashboard_summary(db)
    summary['snapshotDate'] = None
    summary['snapshotGeneratedAt'] = None
    summary['snapshotSource'] = 'live'
    summary['dataMode'] = 'live'
    summary['lifecycle'] = _lifecycle_summary(db, active_only=True)
    return summary
