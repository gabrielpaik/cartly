import hashlib
import hmac
import secrets
from datetime import datetime, timedelta
from typing import Literal, Optional, Tuple

from sqlalchemy import delete, select
from sqlalchemy.orm import Session as OrmSession

from ..db.models import EmailAuthCode, Session, User
from .auth_service import _find_active_guest_by_key, _issue_session, _merge_guest_user_into_member
from .mail_service import send_email

EmailCodePurpose = Literal['signup', 'password_reset']
PASSWORD_HASH_ITERATIONS = 390000
EMAIL_CODE_TTL_MINUTES = 10


class AuthFlowError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message



def _utcnow() -> datetime:
    return datetime.utcnow()



def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, PASSWORD_HASH_ITERATIONS)
    return f'pbkdf2_sha256${PASSWORD_HASH_ITERATIONS}${salt.hex()}${digest.hex()}'



def verify_password(password: str, stored_hash: Optional[str]) -> bool:
    if not stored_hash:
        return False
    try:
        algorithm, iterations_raw, salt_hex, digest_hex = stored_hash.split('$', 3)
        if algorithm != 'pbkdf2_sha256':
            return False
        iterations = int(iterations_raw)
        salt = bytes.fromhex(salt_hex)
        expected = bytes.fromhex(digest_hex)
    except Exception:
        return False

    actual = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, iterations)
    return hmac.compare_digest(actual, expected)



def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode('utf-8')).hexdigest()



def _generate_code() -> str:
    return f'{secrets.randbelow(1000000):06d}'



def _delete_existing_codes(db: OrmSession, *, email: str, purpose: EmailCodePurpose) -> None:
    db.execute(delete(EmailAuthCode).where(EmailAuthCode.email == email, EmailAuthCode.purpose == purpose))
    db.flush()



def _store_code(db: OrmSession, *, email: str, purpose: EmailCodePurpose, code: str) -> EmailAuthCode:
    _delete_existing_codes(db, email=email, purpose=purpose)
    row = EmailAuthCode(
        email=email,
        purpose=purpose,
        code_hash=_hash_code(code),
        expires_at=_utcnow() + timedelta(minutes=EMAIL_CODE_TTL_MINUTES),
        created_at=_utcnow(),
    )
    db.add(row)
    db.flush()
    return row



def _send_code_email(*, email: str, code: str, purpose: EmailCodePurpose) -> None:
    if purpose == 'signup':
        subject = '[Cartly] 이메일 인증 코드 안내'
        text_body = (
            f'안녕하세요. Cartly입니다.\n\n'
            f'이메일 인증 코드: {code}\n\n'
            f'위 코드는 10분 동안 유효합니다.\n'
            f'본인이 요청하지 않으셨다면 이 메일을 무시해 주세요.'
        )
    else:
        subject = '[Cartly] 비밀번호 재설정 코드 안내'
        text_body = (
            f'안녕하세요. Cartly입니다.\n\n'
            f'비밀번호 재설정 코드: {code}\n\n'
            f'위 코드는 10분 동안 유효합니다.\n'
            f'본인이 요청하지 않으셨다면 이 메일을 무시해 주세요.'
        )
    send_email(to_email=email, subject=subject, text_body=text_body)



def request_email_code(db: OrmSession, *, email: str, purpose: EmailCodePurpose) -> None:
    normalized_email = email.strip().lower()
    if not normalized_email:
        raise AuthFlowError('EMAIL_REQUIRED', '이메일을 입력해 주세요')

    if purpose == 'signup':
        existing = db.scalar(select(User).where(User.email == normalized_email, User.status == 'active', User.is_guest.is_(False)))
        if existing is not None and existing.email_verified_at is not None:
            raise AuthFlowError('EMAIL_ALREADY_REGISTERED', '이미 가입된 이메일입니다')
    else:
        existing = db.scalar(select(User).where(User.email == normalized_email, User.status == 'active', User.is_guest.is_(False)))
        if existing is None or not existing.password_hash:
            raise AuthFlowError('EMAIL_NOT_FOUND', '가입된 계정을 찾지 못했습니다')

    code = _generate_code()
    _store_code(db, email=normalized_email, purpose=purpose, code=code)
    _send_code_email(email=normalized_email, code=code, purpose=purpose)
    db.commit()



def validate_email_code(db: OrmSession, *, email: str, purpose: EmailCodePurpose, code: str) -> None:
    normalized_email = email.strip().lower()
    row = db.scalar(
        select(EmailAuthCode).where(
            EmailAuthCode.email == normalized_email,
            EmailAuthCode.purpose == purpose,
            EmailAuthCode.consumed_at.is_(None),
        )
    )
    if row is None:
        raise AuthFlowError('CODE_NOT_FOUND', '인증 코드를 다시 요청해 주세요')
    if row.expires_at <= _utcnow():
        raise AuthFlowError('CODE_EXPIRED', '인증 코드가 만료되었습니다')
    if row.attempt_count >= 5:
        raise AuthFlowError('CODE_ATTEMPTS_EXCEEDED', '인증 코드 입력 시도 횟수를 초과했습니다')

    if not hmac.compare_digest(row.code_hash, _hash_code(code.strip())):
        row.attempt_count += 1
        db.add(row)
        db.commit()
        raise AuthFlowError('CODE_INVALID', '인증 코드가 올바르지 않습니다')



def _consume_valid_code(db: OrmSession, *, email: str, purpose: EmailCodePurpose, code: str) -> EmailAuthCode:
    normalized_email = email.strip().lower()
    row = db.scalar(
        select(EmailAuthCode).where(
            EmailAuthCode.email == normalized_email,
            EmailAuthCode.purpose == purpose,
            EmailAuthCode.consumed_at.is_(None),
        )
    )
    if row is None:
        raise AuthFlowError('CODE_NOT_FOUND', '인증 코드를 다시 요청해 주세요')
    if row.expires_at <= _utcnow():
        raise AuthFlowError('CODE_EXPIRED', '인증 코드가 만료되었습니다')
    if row.attempt_count >= 5:
        raise AuthFlowError('CODE_ATTEMPTS_EXCEEDED', '인증 코드 입력 시도 횟수를 초과했습니다')

    row.attempt_count += 1
    if not hmac.compare_digest(row.code_hash, _hash_code(code.strip())):
        db.add(row)
        db.commit()
        raise AuthFlowError('CODE_INVALID', '인증 코드가 올바르지 않습니다')

    row.consumed_at = _utcnow()
    db.add(row)
    db.flush()
    return row



def register_with_email_password(
    db: OrmSession,
    *,
    email: str,
    display_name: str,
    password: str,
    code: str,
    guest_key: Optional[str],
) -> Tuple[User, Session, str]:
    normalized_email = email.strip().lower()
    if len(password) < 8:
        raise AuthFlowError('PASSWORD_TOO_SHORT', '비밀번호는 8자 이상이어야 합니다')

    _consume_valid_code(db, email=normalized_email, purpose='signup', code=code)

    existing = db.scalar(select(User).where(User.email == normalized_email, User.status == 'active', User.is_guest.is_(False)))
    if existing is not None and existing.email_verified_at is not None:
        raise AuthFlowError('EMAIL_ALREADY_REGISTERED', '이미 가입된 이메일입니다')

    user = existing
    if user is None:
        user = User(
            display_name=display_name.strip() or 'Cartly User',
            email=normalized_email,
            auth_provider='email',
            status='active',
            is_guest=False,
            email_verified_at=_utcnow(),
            password_hash=hash_password(password),
            last_seen_at=_utcnow(),
        )
        db.add(user)
        db.flush()
    else:
        user.display_name = display_name.strip() or user.display_name
        user.auth_provider = 'email'
        user.is_guest = False
        user.email_verified_at = _utcnow()
        user.password_hash = hash_password(password)
        user.last_seen_at = _utcnow()
        user.updated_at = _utcnow()
        db.add(user)
        db.flush()

    guest_user = _find_active_guest_by_key(db, guest_key)
    if guest_user is not None and guest_user.id != user.id:
        _merge_guest_user_into_member(db, guest_user, user)

    session, raw_token = _issue_session(db, user.id, False)
    db.commit()
    db.refresh(user)
    db.refresh(session)
    return user, session, raw_token



def login_with_email_password(
    db: OrmSession,
    *,
    email: str,
    password: str,
    guest_key: Optional[str],
) -> Tuple[User, Session, str]:
    normalized_email = email.strip().lower()
    user = db.scalar(select(User).where(User.email == normalized_email, User.status == 'active', User.is_guest.is_(False)))
    if user is None or not verify_password(password, user.password_hash):
        raise AuthFlowError('INVALID_CREDENTIALS', '이메일 또는 비밀번호가 올바르지 않습니다')
    if user.email_verified_at is None:
        raise AuthFlowError('EMAIL_NOT_VERIFIED', '이메일 인증이 아직 완료되지 않았습니다')

    guest_user = _find_active_guest_by_key(db, guest_key)
    if guest_user is not None and guest_user.id != user.id:
        _merge_guest_user_into_member(db, guest_user, user)

    user.last_seen_at = _utcnow()
    user.updated_at = _utcnow()
    db.add(user)
    session, raw_token = _issue_session(db, user.id, False)
    db.commit()
    db.refresh(user)
    db.refresh(session)
    return user, session, raw_token



def reset_password_with_code(
    db: OrmSession,
    *,
    email: str,
    code: str,
    new_password: str,
) -> Tuple[User, Session, str]:
    normalized_email = email.strip().lower()
    if len(new_password) < 8:
        raise AuthFlowError('PASSWORD_TOO_SHORT', '비밀번호는 8자 이상이어야 합니다')

    user = db.scalar(select(User).where(User.email == normalized_email, User.status == 'active', User.is_guest.is_(False)))
    if user is None:
        raise AuthFlowError('EMAIL_NOT_FOUND', '가입된 계정을 찾지 못했습니다')

    _consume_valid_code(db, email=normalized_email, purpose='password_reset', code=code)
    user.password_hash = hash_password(new_password)
    user.email_verified_at = user.email_verified_at or _utcnow()
    user.last_seen_at = _utcnow()
    user.updated_at = _utcnow()
    db.add(user)
    session, raw_token = _issue_session(db, user.id, False)
    db.commit()
    db.refresh(user)
    db.refresh(session)
    return user, session, raw_token
