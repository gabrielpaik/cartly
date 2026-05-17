import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Literal, Optional, Tuple

from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session as OrmSession

from ..db.models import (
    AdImpression,
    AppEvent,
    Cart,
    CartItem,
    EmailAuthCode,
    PushDevice,
    Receipt,
    ReceiptLineItem,
    ScanFailureLog,
    ScanFeedback,
    ScanJob,
    Session,
    User,
    UserRegionEvent,
    UserRegionProfile,
)

AuthProvider = Literal['email', 'google', 'kakao']

GUEST_CODE_SPACE = 10_000


class AccountDeletionError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode('utf-8')).hexdigest()


def _issue_session(db: OrmSession, user_id: Optional[str], is_guest: bool) -> Tuple[Session, str]:
    raw_token = secrets.token_urlsafe(32)
    session = Session(
        user_id=user_id,
        token_hash=_hash_token(raw_token),
        is_guest=is_guest,
        expires_at=datetime.utcnow() + timedelta(days=7),
        created_at=datetime.utcnow(),
        last_seen_at=datetime.utcnow(),
    )
    db.add(session)
    db.flush()
    return session, raw_token


def _find_active_guest_by_key(db: OrmSession, guest_key: Optional[str]) -> Optional[User]:
    normalized_guest_key = (guest_key or '').strip() or None
    if not normalized_guest_key:
        return None
    return db.scalar(
        select(User).where(
            User.is_guest.is_(True),
            User.status == 'active',
            User.guest_key == normalized_guest_key,
        )
    )


def _format_guest_code(value: int) -> str:
    return f'{value:04d}'


def _guest_display_name(code: str) -> str:
    return f'Guest#{code}'


def _allocate_guest_code(db: OrmSession) -> str:
    used_codes = {
        (code or '').strip()
        for code in db.scalars(select(User.guest_code).where(User.guest_code.is_not(None))).all()
    }

    for _ in range(GUEST_CODE_SPACE):
        candidate = _format_guest_code(secrets.randbelow(GUEST_CODE_SPACE))
        if candidate not in used_codes:
            return candidate

    for value in range(GUEST_CODE_SPACE):
        candidate = _format_guest_code(value)
        if candidate not in used_codes:
            return candidate

    raise RuntimeError('사용 가능한 guest code가 없어')


def _ensure_guest_identity(db: OrmSession, user: User) -> None:
    if not user.is_guest:
        return

    guest_code = (user.guest_code or '').strip()
    if not guest_code:
        guest_code = _allocate_guest_code(db)
        user.guest_code = guest_code

    expected_name = _guest_display_name(guest_code)
    if (user.display_name or '').strip() != expected_name:
        user.display_name = expected_name


def _merge_guest_user_into_member(db: OrmSession, guest_user: User, member_user: User) -> None:
    if guest_user.id == member_user.id:
        return

    db.execute(
        update(Cart)
        .where(Cart.user_id == guest_user.id)
        .values(
            user_id=member_user.id,
            expires_at=None,
            retention_extension_count=0,
            updated_at=datetime.utcnow(),
        )
    )
    db.execute(update(ScanJob).where(ScanJob.user_id == guest_user.id).values(user_id=member_user.id))
    db.execute(update(ScanFeedback).where(ScanFeedback.user_id == guest_user.id).values(user_id=member_user.id))
    db.execute(update(ScanFailureLog).where(ScanFailureLog.user_id == guest_user.id).values(user_id=member_user.id))
    db.execute(update(AppEvent).where(AppEvent.user_id == guest_user.id).values(user_id=member_user.id))
    db.execute(update(AdImpression).where(AdImpression.user_id == guest_user.id).values(user_id=member_user.id))

    db.execute(update(Session).where(Session.user_id == guest_user.id).values(user_id=member_user.id, is_guest=False))

    if guest_user.last_seen_at and (member_user.last_seen_at is None or guest_user.last_seen_at > member_user.last_seen_at):
        member_user.last_seen_at = guest_user.last_seen_at
    if not member_user.last_device_platform and guest_user.last_device_platform:
        member_user.last_device_platform = guest_user.last_device_platform
    if not member_user.last_app_version and guest_user.last_app_version:
        member_user.last_app_version = guest_user.last_app_version

    guest_user.status = 'merged'
    guest_user.guest_key = None
    guest_user.guest_code = None
    guest_user.merged_into_user_id = member_user.id
    guest_user.merged_at = datetime.utcnow()
    guest_user.updated_at = datetime.utcnow()
    db.add(member_user)
    db.add(guest_user)
    db.flush()


def create_guest_session(
    db: OrmSession,
    *,
    guest_key: Optional[str] = None,
    platform: Optional[str] = None,
    app_version: Optional[str] = None,
) -> Tuple[User, Session, str]:
    normalized_guest_key = (guest_key or '').strip() or None

    user = _find_active_guest_by_key(db, normalized_guest_key)

    if user is None:
        user = User(
            display_name='Guest',
            email=None,
            auth_provider='guest',
            status='active',
            is_guest=True,
            guest_key=normalized_guest_key,
            last_device_platform=(platform or '').strip() or None,
            last_app_version=(app_version or '').strip() or None,
            last_seen_at=datetime.utcnow(),
        )
        db.add(user)
        db.flush()
    else:
        user.last_seen_at = datetime.utcnow()
        if normalized_guest_key:
            user.guest_key = normalized_guest_key
        if (platform or '').strip():
            user.last_device_platform = platform.strip()
        if (app_version or '').strip():
            user.last_app_version = app_version.strip()
        user.updated_at = datetime.utcnow()
        db.add(user)
        db.flush()

    _ensure_guest_identity(db, user)
    db.add(user)
    db.flush()

    session, raw_token = _issue_session(db, user.id, True)
    db.commit()
    db.refresh(user)
    db.refresh(session)
    return user, session, raw_token


def login_or_create_user(
    db: OrmSession,
    email: str,
    display_name: str,
    provider: AuthProvider = 'email',
    *,
    guest_key: Optional[str] = None,
) -> Tuple[User, Session, str]:
    stmt = select(User).where(User.email == email)
    user = db.scalar(stmt)

    if user is None:
        user = User(
            display_name=display_name,
            email=email,
            auth_provider=provider,
            status='active',
            is_guest=False,
            last_seen_at=datetime.utcnow(),
        )
        db.add(user)
        db.flush()
    else:
        user.display_name = display_name or user.display_name
        user.is_guest = False
        user.auth_provider = provider
        user.last_seen_at = datetime.utcnow()
        user.updated_at = datetime.utcnow()

    guest_user = _find_active_guest_by_key(db, guest_key)
    if guest_user is not None and guest_user.id != user.id:
        _merge_guest_user_into_member(db, guest_user, user)

    session, raw_token = _issue_session(db, user.id, False)
    db.commit()
    db.refresh(user)
    db.refresh(session)
    return user, session, raw_token


def revoke_session_by_token(db: OrmSession, token: str) -> bool:
    token_hash = _hash_token(token)
    session = db.scalar(select(Session).where(Session.token_hash == token_hash))
    if session is None:
        return False
    db.delete(session)
    db.commit()
    return True


def get_user_by_token(db: OrmSession, token: str) -> Optional[User]:
    token_hash = _hash_token(token)
    stmt = select(Session).where(Session.token_hash == token_hash)
    session = db.scalar(stmt)
    if session is None:
        return None
    if session.expires_at is not None and session.expires_at <= datetime.utcnow():
        db.delete(session)
        db.commit()
        return None
    if session.user_id is None:
        return None
    session.last_seen_at = datetime.utcnow()
    db.add(session)
    user = db.get(User, session.user_id)
    if user is not None:
        user.last_seen_at = datetime.utcnow()
        db.add(user)
    db.commit()
    return user


def delete_account(db: OrmSession, user: Optional[User]) -> User:
    if user is None:
        raise AccountDeletionError('UNAUTHORIZED', '로그인이 필요합니다')
    if user.status != 'active':
        raise AccountDeletionError('ACCOUNT_NOT_ACTIVE', '이미 비활성화된 계정입니다')
    if user.is_guest:
        raise AccountDeletionError('GUEST_ACCOUNT_NOT_SUPPORTED', '게스트 계정은 탈퇴할 수 없어요. 회원 계정으로 로그인해 주세요')

    now = datetime.utcnow()
    original_email = (user.email or '').strip().lower()

    session_ids = list(db.scalars(select(Session.id).where(Session.user_id == user.id)).all())

    if session_ids:
        db.execute(delete(AppEvent).where(AppEvent.session_id.in_(session_ids)))
        db.execute(update(ScanJob).where(ScanJob.session_id.in_(session_ids)).values(session_id=None, updated_at=now))
        db.execute(update(AdImpression).where(AdImpression.session_id.in_(session_ids)).values(session_id=None))

    receipt_ids = list(db.scalars(select(Receipt.id).where(Receipt.user_id == user.id)).all())
    if receipt_ids:
        db.execute(delete(ReceiptLineItem).where(ReceiptLineItem.receipt_id.in_(receipt_ids)))
        db.execute(delete(Receipt).where(Receipt.id.in_(receipt_ids)))

    db.execute(delete(UserRegionEvent).where(UserRegionEvent.user_id == user.id))
    db.execute(delete(UserRegionProfile).where(UserRegionProfile.user_id == user.id))
    db.execute(delete(ScanFeedback).where(ScanFeedback.user_id == user.id))
    db.execute(delete(ScanFailureLog).where(ScanFailureLog.user_id == user.id))
    db.execute(delete(ScanJob).where(ScanJob.user_id == user.id))
    db.execute(delete(AppEvent).where(AppEvent.user_id == user.id))
    db.execute(delete(AdImpression).where(AdImpression.user_id == user.id))
    db.execute(delete(CartItem).where(CartItem.cart_id.in_(select(Cart.id).where(Cart.user_id == user.id))))
    db.execute(delete(Cart).where(Cart.user_id == user.id))
    db.execute(delete(Session).where(Session.user_id == user.id))
    db.execute(
        update(PushDevice)
        .where(PushDevice.user_id == user.id)
        .values(
            user_id=None,
            push_token=None,
            push_provider=None,
            notifications_enabled=False,
            status='deleted',
            push_debug_json=None,
            updated_at=now,
            last_seen_at=now,
        )
    )

    if original_email:
        db.execute(delete(EmailAuthCode).where(EmailAuthCode.email == original_email))

    user.display_name = 'Deleted User'
    user.email = None
    user.auth_provider = 'deleted'
    user.status = 'deleted'
    user.is_guest = False
    user.guest_code = None
    user.password_hash = None
    user.email_verified_at = None
    user.guest_key = None
    user.last_device_platform = None
    user.last_app_version = None
    user.merged_into_user_id = None
    user.merged_at = None
    user.last_region_city = None
    user.last_region_district = None
    user.last_region_neighborhood = None
    user.last_region_label = None
    user.last_region_captured_at = None
    user.last_seen_at = None
    user.updated_at = now
    db.add(user)
    db.commit()
    db.refresh(user)
    return user
