from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..schemas.auth import GuestLoginRequest, LoginRequest
from ..services.auth_service import create_guest_session, login_or_create_user

router = APIRouter()


@router.post('/guest')
def guest_login(payload: GuestLoginRequest, db: OrmSession = Depends(db_dep)):
    user, session, token = create_guest_session(db)
    return {
        'ok': True,
        'data': {
            'user': {
                'id': user.id,
                'displayName': user.display_name,
                'email': user.email,
                'isGuest': user.is_guest,
            },
            'session': {
                'token': token,
                'expiresAt': session.expires_at.isoformat() if session.expires_at else None,
            },
        },
    }


@router.post('/login')
def login(payload: LoginRequest, db: OrmSession = Depends(db_dep)):
    user, session, token = login_or_create_user(db, payload.email, payload.displayName)
    return {
        'ok': True,
        'data': {
            'user': {
                'id': user.id,
                'displayName': user.display_name,
                'email': user.email,
                'isGuest': user.is_guest,
            },
            'session': {
                'token': token,
                'expiresAt': session.expires_at.isoformat() if session.expires_at else None,
            },
        },
    }


@router.post('/logout')
def logout():
    return {'ok': True, 'data': {'loggedOut': True}}


@router.get('/me')
def me(current_user=Depends(current_user_dep)):
    if current_user is None:
        return {
            'ok': False,
            'error': {
                'code': 'UNAUTHORIZED',
                'message': '로그인이 필요해',
            },
        }

    return {
        'ok': True,
        'data': {
            'user': {
                'id': current_user.id,
                'displayName': current_user.display_name,
                'email': current_user.email,
                'isGuest': current_user.is_guest,
            }
        },
    }
