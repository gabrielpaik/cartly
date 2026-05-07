import uuid
from datetime import date, datetime
from typing import List, Optional

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base


class User(Base):
    __tablename__ = 'users'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email: Mapped[Optional[str]] = mapped_column(String(255), unique=True, nullable=True)
    display_name: Mapped[str] = mapped_column(String(120))
    auth_provider: Mapped[str] = mapped_column(String(30), default='guest')
    status: Mapped[str] = mapped_column(String(20), default='active')
    is_guest: Mapped[bool] = mapped_column(Boolean, default=False)
    guest_code: Mapped[Optional[str]] = mapped_column(String(4), unique=True, nullable=True)
    password_hash: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    email_verified_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    guest_key: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    last_device_platform: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    last_app_version: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    merged_into_user_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
    merged_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


class Session(Base):
    __tablename__ = 'sessions'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), nullable=True)
    token_hash: Mapped[str] = mapped_column(String(255))
    is_guest: Mapped[bool] = mapped_column(Boolean, default=False)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped[Optional['User']] = relationship()


class AdminSession(Base):
    __tablename__ = 'admin_sessions'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    token_hash: Mapped[str] = mapped_column(String(255), unique=True)
    status: Mapped[str] = mapped_column(String(20), default='active')
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    revoked_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


class ScanJob(Base):
    __tablename__ = 'scan_jobs'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), nullable=True)
    session_id: Mapped[Optional[str]] = mapped_column(ForeignKey('sessions.id'), nullable=True)
    source_image_path: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default='queued')
    error_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    started_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    finished_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ScanFeedback(Base):
    __tablename__ = 'scan_feedback'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    scan_job_id: Mapped[str] = mapped_column(ForeignKey('scan_jobs.id'))
    user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), nullable=True)
    accepted: Mapped[bool] = mapped_column(Boolean, default=False)
    original_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    corrected_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ScanFailureLog(Base):
    __tablename__ = 'scan_failure_logs'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    scan_job_id: Mapped[str] = mapped_column(ForeignKey('scan_jobs.id'))
    user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), nullable=True)
    stage: Mapped[str] = mapped_column(String(50), default='processing')
    error_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    details_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Cart(Base):
    __tablename__ = 'carts'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), nullable=True)
    source_cart_id: Mapped[Optional[str]] = mapped_column(String(36), nullable=True)
    title: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default='active')
    saved_date: Mapped[date] = mapped_column(Date, default=date.today)
    total_price_cached: Mapped[int] = mapped_column(Integer, default=0)
    total_count_cached: Mapped[int] = mapped_column(Integer, default=0)
    expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    retention_extension_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    deleted_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    items: Mapped[List['CartItem']] = relationship(back_populates='cart', cascade='all, delete-orphan')


class CartItem(Base):
    __tablename__ = 'cart_items'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    cart_id: Mapped[str] = mapped_column(ForeignKey('carts.id'))
    scan_job_id: Mapped[Optional[str]] = mapped_column(ForeignKey('scan_jobs.id'), nullable=True)
    name: Mapped[str] = mapped_column(String(255))
    original_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    price: Mapped[int] = mapped_column(Integer)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    source: Mapped[str] = mapped_column(String(20), default='manual')
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    cart: Mapped['Cart'] = relationship(back_populates='items')


class Receipt(Base):
    __tablename__ = 'receipts'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id'))
    saved_cart_id: Mapped[str] = mapped_column(ForeignKey('carts.id'))
    status: Mapped[str] = mapped_column(String(20), default='processing')
    image_path: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    image_filename: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    merchant_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    purchased_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    currency: Mapped[str] = mapped_column(String(10), default='KRW')
    subtotal: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    tax: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    total_amount: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    total_discount_amount: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    raw_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    line_items: Mapped[List['ReceiptLineItem']] = relationship(back_populates='receipt', cascade='all, delete-orphan')


class ReceiptLineItem(Base):
    __tablename__ = 'receipt_line_items'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    receipt_id: Mapped[str] = mapped_column(ForeignKey('receipts.id'))
    raw_name: Mapped[str] = mapped_column(String(255))
    normalized_name: Mapped[str] = mapped_column(String(255))
    quantity: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    unit_price: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    line_amount: Mapped[int] = mapped_column(Integer)
    final_amount: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    category: Mapped[str] = mapped_column(String(20), default='item')
    confidence: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    receipt: Mapped['Receipt'] = relationship(back_populates='line_items')


class AppEvent(Base):
    __tablename__ = 'app_events'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), nullable=True)
    session_id: Mapped[Optional[str]] = mapped_column(ForeignKey('sessions.id'), nullable=True)
    event_name: Mapped[str] = mapped_column(String(80))
    screen_name: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    event_props_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    client_timestamp: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    device_platform: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    device_type: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    os_name: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    os_version: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    app_version: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AdSlot(Base):
    __tablename__ = 'ad_slots'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    slot_key: Mapped[str] = mapped_column(String(120), unique=True)
    placement_type: Mapped[str] = mapped_column(String(50))
    status: Mapped[str] = mapped_column(String(20), default='active')
    config_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class AdCampaign(Base):
    __tablename__ = 'ad_campaigns'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    slot_id: Mapped[str] = mapped_column(ForeignKey('ad_slots.id'))
    variant: Mapped[str] = mapped_column(String(20), default='live')
    status: Mapped[str] = mapped_column(String(20), default='draft')
    title: Mapped[str] = mapped_column(String(255), default='')
    message: Mapped[str] = mapped_column(Text, default='')
    cta_label: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    target_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    start_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    end_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class AdImpression(Base):
    __tablename__ = 'ad_impressions'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    slot_id: Mapped[str] = mapped_column(ForeignKey('ad_slots.id'))
    user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), nullable=True)
    session_id: Mapped[Optional[str]] = mapped_column(ForeignKey('sessions.id'), nullable=True)
    screen_name: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    campaign_id: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    creative_id: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AdClick(Base):
    __tablename__ = 'ad_clicks'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    impression_id: Mapped[str] = mapped_column(ForeignKey('ad_impressions.id'))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AppSetting(Base):
    __tablename__ = 'app_settings'

    key: Mapped[str] = mapped_column(String(120), primary_key=True)
    value_json: Mapped[str] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class PushDevice(Base):
    __tablename__ = 'push_devices'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[Optional[str]] = mapped_column(ForeignKey('users.id'), nullable=True)
    install_id: Mapped[str] = mapped_column(String(120), index=True)
    platform: Mapped[str] = mapped_column(String(40), default='unknown')
    push_provider: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    push_token: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    status: Mapped[str] = mapped_column(String(20), default='active')
    app_version: Mapped[Optional[str]] = mapped_column(String(80), nullable=True)
    locale: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    push_debug_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    last_registered_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class PushCampaign(Base):
    __tablename__ = 'push_campaigns'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    kind: Mapped[str] = mapped_column(String(40), default='notice')
    audience: Mapped[str] = mapped_column(String(40), default='all')
    status: Mapped[str] = mapped_column(String(20), default='draft')
    title: Mapped[str] = mapped_column(String(255), default='')
    message: Mapped[str] = mapped_column(Text, default='')
    target_tab: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    target_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    requested_by: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    requested_by_source: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    delivery_provider: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    sent_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class EmailAuthCode(Base):
    __tablename__ = 'email_auth_codes'

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email: Mapped[str] = mapped_column(String(255), index=True)
    purpose: Mapped[str] = mapped_column(String(40), index=True)
    code_hash: Mapped[str] = mapped_column(String(255))
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    consumed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    attempt_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AdminDashboardSnapshot(Base):
    __tablename__ = 'admin_dashboard_snapshots'

    snapshot_date: Mapped[date] = mapped_column(Date, primary_key=True)
    source: Mapped[str] = mapped_column(String(20), default='scheduled')
    dau: Mapped[int] = mapped_column(Integer, default=0)
    wau: Mapped[int] = mapped_column(Integer, default=0)
    mau: Mapped[int] = mapped_column(Integer, default=0)
    active_users: Mapped[int] = mapped_column(Integer, default=0)
    new_users: Mapped[int] = mapped_column(Integer, default=0)
    guest_to_member_conversion: Mapped[float] = mapped_column(Float, default=0.0)
    total_scans: Mapped[int] = mapped_column(Integer, default=0)
    scan_success_rate: Mapped[float] = mapped_column(Float, default=0.0)
    cart_save_rate: Mapped[float] = mapped_column(Float, default=0.0)
    ad_impressions: Mapped[int] = mapped_column(Integer, default=0)
    ad_clicks: Mapped[int] = mapped_column(Integer, default=0)
    ad_ctr: Mapped[float] = mapped_column(Float, default=0.0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
