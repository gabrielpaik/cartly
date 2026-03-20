from typing import Optional

from fastapi import Depends, Header
from sqlalchemy.orm import Session as OrmSession

from .db.session import get_db
from .services.auth_service import get_user_by_token


def db_dep(db: OrmSession = Depends(get_db)) -> OrmSession:
    return db


def bearer_token_dep(authorization: Optional[str] = Header(default=None)) -> Optional[str]:
    if not authorization:
        return None
    prefix = 'Bearer '
    if authorization.startswith(prefix):
        return authorization[len(prefix):].strip()
    return None


def current_user_dep(
    db: OrmSession = Depends(get_db),
    token: Optional[str] = Depends(bearer_token_dep),
):
    if not token:
        return None
    return get_user_by_token(db, token)
