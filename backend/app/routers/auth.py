from fastapi import APIRouter

from ..schemas.auth import GuestLoginRequest, LoginRequest

router = APIRouter()


@router.post('/guest')
def guest_login(payload: GuestLoginRequest):
    return {
        'ok': True,
        'data': {
            'user': {
                'id': 'usr_guest_placeholder',
                'displayName': 'Guest',
                'email': None,
                'isGuest': True,
            },
            'session': {
                'token': 'guest_token_placeholder',
                'expiresAt': '2026-03-27T12:00:00Z',
            },
        },
    }


@router.post('/login')
def login(payload: LoginRequest):
    return {
        'ok': True,
        'data': {
            'user': {
                'id': 'usr_placeholder',
                'displayName': payload.displayName,
                'email': payload.email,
                'isGuest': False,
            },
            'session': {
                'token': 'session_token_placeholder',
                'expiresAt': '2026-03-27T12:00:00Z',
            },
        },
    }


@router.post('/logout')
def logout():
    return {'ok': True, 'data': {'loggedOut': True}}


@router.get('/me')
def me():
    return {
        'ok': True,
        'data': {
            'user': {
                'id': 'usr_placeholder',
                'displayName': 'WIMC User',
                'email': 'user@example.com',
                'isGuest': False,
            }
        },
    }
