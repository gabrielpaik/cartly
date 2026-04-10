from typing import Optional

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..deps import bearer_token_dep, current_user_dep, db_dep
from ..schemas.auth import (
    EmailCodeRequest,
    EmailCodeVerifyRequest,
    EmailRegisterRequest,
    GuestLoginRequest,
    LoginRequest,
    PasswordLoginRequest,
    PasswordResetConfirmRequest,
    PasswordResetRequest,
)
from ..services.auth_password_service import (
    AuthFlowError,
    login_with_email_password,
    register_with_email_password,
    request_email_code,
    reset_password_with_code,
    validate_email_code,
)
from ..services.auth_service import create_guest_session, login_or_create_user, revoke_session_by_token

router = APIRouter()


def _auth_error(exc: AuthFlowError):
    return {
        'ok': False,
        'error': {
            'code': exc.code,
            'message': exc.message,
        },
    }


@router.post('/guest')
def guest_login(payload: GuestLoginRequest, db: OrmSession = Depends(db_dep)):
    user, session, token = create_guest_session(
        db,
        guest_key=payload.deviceId,
        platform=payload.platform,
        app_version=payload.appVersion,
    )
    return {
        'ok': True,
        'data': {
            'user': {
                'id': user.id,
                'displayName': user.display_name,
                'guestCode': user.guest_code,
                'email': user.email,
                'provider': user.auth_provider,
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
    user, session, token = login_or_create_user(
        db,
        payload.email,
        payload.displayName,
        provider=payload.provider,
        guest_key=payload.deviceId,
    )
    return {
        'ok': True,
        'data': {
            'user': {
                'id': user.id,
                'displayName': user.display_name,
                'guestCode': user.guest_code,
                'email': user.email,
                'provider': user.auth_provider,
                'isGuest': user.is_guest,
            },
            'session': {
                'token': token,
                'expiresAt': session.expires_at.isoformat() if session.expires_at else None,
            },
        },
    }


@router.post('/email/request-signup-code')
def request_signup_code(payload: EmailCodeRequest, db: OrmSession = Depends(db_dep)):
    try:
        request_email_code(db, email=payload.email, purpose='signup')
    except AuthFlowError as exc:
        return _auth_error(exc)
    return {'ok': True, 'data': {'sent': True}}


@router.post('/email/verify-signup-code')
def verify_signup_code(payload: EmailCodeVerifyRequest, db: OrmSession = Depends(db_dep)):
    try:
        validate_email_code(db, email=payload.email, purpose='signup', code=payload.code)
    except AuthFlowError as exc:
        return _auth_error(exc)
    return {'ok': True, 'data': {'verified': True}}


@router.post('/email/register')
def register_email(payload: EmailRegisterRequest, db: OrmSession = Depends(db_dep)):
    try:
        user, session, token = register_with_email_password(
            db,
            email=payload.email,
            display_name=payload.displayName,
            password=payload.password,
            code=payload.code,
            guest_key=payload.deviceId,
        )
    except AuthFlowError as exc:
        return _auth_error(exc)
    return {
        'ok': True,
        'data': {
            'user': {
                'id': user.id,
                'displayName': user.display_name,
                'guestCode': user.guest_code,
                'email': user.email,
                'provider': user.auth_provider,
                'isGuest': user.is_guest,
            },
            'session': {
                'token': token,
                'expiresAt': session.expires_at.isoformat() if session.expires_at else None,
            },
        },
    }


@router.post('/password/login')
def password_login(payload: PasswordLoginRequest, db: OrmSession = Depends(db_dep)):
    try:
        user, session, token = login_with_email_password(
            db,
            email=payload.email,
            password=payload.password,
            guest_key=payload.deviceId,
        )
    except AuthFlowError as exc:
        return _auth_error(exc)
    return {
        'ok': True,
        'data': {
            'user': {
                'id': user.id,
                'displayName': user.display_name,
                'guestCode': user.guest_code,
                'email': user.email,
                'provider': user.auth_provider,
                'isGuest': user.is_guest,
            },
            'session': {
                'token': token,
                'expiresAt': session.expires_at.isoformat() if session.expires_at else None,
            },
        },
    }


@router.post('/password/request-reset-code')
def request_password_reset_code(payload: PasswordResetRequest, db: OrmSession = Depends(db_dep)):
    try:
        request_email_code(db, email=payload.email, purpose='password_reset')
    except AuthFlowError as exc:
        return _auth_error(exc)
    return {'ok': True, 'data': {'sent': True}}


@router.post('/password/reset')
def password_reset(payload: PasswordResetConfirmRequest, db: OrmSession = Depends(db_dep)):
    try:
        user, session, token = reset_password_with_code(
            db,
            email=payload.email,
            code=payload.code,
            new_password=payload.newPassword,
        )
    except AuthFlowError as exc:
        return _auth_error(exc)
    return {
        'ok': True,
        'data': {
            'user': {
                'id': user.id,
                'displayName': user.display_name,
                'guestCode': user.guest_code,
                'email': user.email,
                'provider': user.auth_provider,
                'isGuest': user.is_guest,
            },
            'session': {
                'token': token,
                'expiresAt': session.expires_at.isoformat() if session.expires_at else None,
            },
        },
    }


@router.post('/logout')
def logout(
    db: OrmSession = Depends(db_dep),
    token: Optional[str] = Depends(bearer_token_dep),
):
    if token:
        revoke_session_by_token(db, token)
    return {'ok': True, 'data': {'loggedOut': True}}


@router.get('/me')
def me(current_user=Depends(current_user_dep)):
    if current_user is None:
        return {
            'ok': False,
            'error': {
                'code': 'UNAUTHORIZED',
                'message': '로그인이 필요합니다',
            },
        }

    return {
        'ok': True,
        'data': {
            'user': {
                'id': current_user.id,
                'displayName': current_user.display_name,
                'guestCode': current_user.guest_code,
                'email': current_user.email,
                'provider': current_user.auth_provider,
                'isGuest': current_user.is_guest,
            }
        },
    }
