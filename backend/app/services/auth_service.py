import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, Tuple

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from ..db.models import Session, User


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


def create_guest_session(db: OrmSession) -> Tuple[User, Session, str]:
    user = User(
        display_name='Guest',
        email=None,
        auth_provider='guest',
        status='active',
        is_guest=True,
    )
    db.add(user)
    db.flush()

    session, raw_token = _issue_session(db, user.id, True)
    db.commit()
    db.refresh(user)
    db.refresh(session)
    return user, session, raw_token


def login_or_create_user(db: OrmSession, email: str, display_name: str) -> Tuple[User, Session, str]:
    stmt = select(User).where(User.email == email)
    user = db.scalar(stmt)

    if user is None:
        user = User(
            display_name=display_name,
            email=email,
            auth_provider='email',
            status='active',
            is_guest=False,
        )
        db.add(user)
        db.flush()
    else:
        user.display_name = display_name or user.display_name
        user.is_guest = False
        user.auth_provider = 'email'
        user.updated_at = datetime.utcnow()

    session, raw_token = _issue_session(db, user.id, False)
    db.commit()
    db.refresh(user)
    db.refresh(session)
    return user, session, raw_token


def get_user_by_token(db: OrmSession, token: str) -> Optional[User]:
    token_hash = _hash_token(token)
    stmt = select(Session).where(Session.token_hash == token_hash)
    session = db.scalar(stmt)
    if session is None:
        return None
    if session.user_id is None:
        return None
    return db.get(User, session.user_id)
