import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, Tuple

from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from ..db.models import AdminSession


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode('utf-8')).hexdigest()


def issue_admin_session(db: OrmSession, ttl_hours: int = 12) -> Tuple[AdminSession, str]:
    raw_token = secrets.token_urlsafe(32)
    session = AdminSession(
        token_hash=_hash_token(raw_token),
        status='active',
        expires_at=datetime.utcnow() + timedelta(hours=ttl_hours),
        created_at=datetime.utcnow(),
        last_seen_at=datetime.utcnow(),
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session, raw_token


def get_admin_session_by_token(db: OrmSession, token: str) -> Optional[AdminSession]:
    token_hash = _hash_token(token)
    session = db.scalar(select(AdminSession).where(AdminSession.token_hash == token_hash))
    if session is None:
        return None
    if session.status != 'active':
        return None
    if session.expires_at is not None and session.expires_at <= datetime.utcnow():
        session.status = 'expired'
        db.add(session)
        db.commit()
        return None

    session.last_seen_at = datetime.utcnow()
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def revoke_admin_session(db: OrmSession, token: str) -> bool:
    token_hash = _hash_token(token)
    session = db.scalar(select(AdminSession).where(AdminSession.token_hash == token_hash))
    if session is None:
        return False
    session.status = 'revoked'
    session.revoked_at = datetime.utcnow()
    db.add(session)
    db.commit()
    return True
