from dataclasses import dataclass
from typing import Literal, Optional

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session as OrmSession

from .core.settings import settings
from .db.session import get_db
from .services.admin_auth_service import get_admin_session_by_token
from .services.auth_service import get_user_by_token


@dataclass
class AdminAuthContext:
    token: str
    source: Literal['root_token', 'admin_session']


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


def admin_token_dep(
    db: OrmSession = Depends(get_db),
    authorization: Optional[str] = Header(default=None),
    x_admin_token: Optional[str] = Header(default=None),
) -> AdminAuthContext:
    configured = settings.admin_token.strip()
    if not configured:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                'code': 'ADMIN_TOKEN_NOT_CONFIGURED',
                'message': 'ADMIN_TOKEN 환경변수가 아직 설정되지 않았어',
            },
        )

    token = bearer_token_dep(authorization) or (x_admin_token or '').strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                'code': 'ADMIN_UNAUTHORIZED',
                'message': 'admin 인증이 필요해',
            },
            headers={'WWW-Authenticate': 'Bearer'},
        )

    if token == configured:
        return AdminAuthContext(token=token, source='root_token')

    admin_session = get_admin_session_by_token(db, token)
    if admin_session is not None:
        return AdminAuthContext(token=token, source='admin_session')

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={
            'code': 'ADMIN_UNAUTHORIZED',
            'message': 'admin 인증이 필요해',
        },
        headers={'WWW-Authenticate': 'Bearer'},
    )
