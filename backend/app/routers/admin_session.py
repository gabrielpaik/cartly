from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..deps import AdminAuthContext, admin_token_dep, db_dep
from ..services.admin_auth_service import issue_admin_session, revoke_admin_session
from .admin_common import ADMIN_ROUTE_DEP

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/session')
def admin_session(auth: AdminAuthContext = Depends(admin_token_dep), db: OrmSession = Depends(db_dep)):
    if auth.source == 'root_token':
        session, raw_token = issue_admin_session(db)
        return {
            'ok': True,
            'data': {
                'role': 'admin',
                'mode': 'session',
                'session': {
                    'token': raw_token,
                    'expiresAt': session.expires_at.isoformat() if session.expires_at else None,
                },
            },
        }

    return {
        'ok': True,
        'data': {
            'role': 'admin',
            'mode': 'session',
        },
    }


@router.post('/logout')
def admin_logout(auth: AdminAuthContext = Depends(admin_token_dep), db: OrmSession = Depends(db_dep)):
    if auth.source == 'admin_session':
        revoke_admin_session(db, auth.token)
    return {'ok': True, 'data': {'loggedOut': True}}
