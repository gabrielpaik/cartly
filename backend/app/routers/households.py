from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..deps import current_user_dep, db_dep
from ..services.household_service import (
    HouseholdError,
    ensure_member_can_use_household,
    generate_invite_code,
    join_household_by_invite_code,
    leave_household,
    serialize_household_state,
)

router = APIRouter()


class _JoinPayload:
    def __init__(self, inviteCode: str):
        self.inviteCode = inviteCode


def _error(exc: HouseholdError):
    return {'ok': False, 'error': {'code': exc.code, 'message': exc.message}}


@router.get('/me')
def get_household_me(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': serialize_household_state(db, user)}


@router.post('/invite-code')
def create_invite_code(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
        generate_invite_code(db, user)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': serialize_household_state(db, user)}


from pydantic import BaseModel


class JoinHouseholdRequest(BaseModel):
    inviteCode: str


@router.post('/join')
def join_household(
    payload: JoinHouseholdRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
        join_household_by_invite_code(db, user, payload.inviteCode)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': serialize_household_state(db, user)}


@router.post('/leave')
def leave_household_route(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    try:
        user = ensure_member_can_use_household(current_user)
        leave_household(db, user)
    except HouseholdError as exc:
        return _error(exc)
    return {'ok': True, 'data': serialize_household_state(db, user)}
