import random
import string
from datetime import datetime
from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.orm import Session as OrmSession

from ..db.models import Household, HouseholdMembership, User


class HouseholdError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code
        self.message = message


def _clean_name(user: User) -> str:
    name = (user.display_name or '').strip()
    return f'{name}의 가족' if name else '우리 집'


def _generate_invite_code() -> str:
    alphabet = string.ascii_uppercase + string.digits
    return ''.join(random.choice(alphabet) for _ in range(6))


def get_membership(db: OrmSession, user_id: str) -> Optional[HouseholdMembership]:
    return db.scalar(select(HouseholdMembership).where(HouseholdMembership.user_id == user_id))


def get_household_for_user(db: OrmSession, user_id: str) -> Optional[Household]:
    membership = get_membership(db, user_id)
    if membership is None:
        return None
    return db.get(Household, membership.household_id)


def list_household_member_ids(db: OrmSession, household_id: str) -> list[str]:
    return list(db.scalars(select(HouseholdMembership.user_id).where(HouseholdMembership.household_id == household_id)).all())


def ensure_member_can_use_household(user: Optional[User]) -> User:
    if user is None:
        raise HouseholdError('UNAUTHORIZED', '로그인이 필요해')
    if user.is_guest:
        raise HouseholdError('HOUSEHOLD_MEMBER_ONLY', '가족 공유는 회원만 사용할 수 있어')
    return user


def ensure_household_for_user(db: OrmSession, user: User) -> tuple[Household, HouseholdMembership]:
    existing = get_membership(db, user.id)
    if existing is not None:
        household = db.get(Household, existing.household_id)
        if household is None:
            raise HouseholdError('HOUSEHOLD_NOT_FOUND', '가족 정보를 찾지 못했어')
        return household, existing

    household = Household(
        name=_clean_name(user),
        created_by_user_id=user.id,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(household)
    db.flush()
    membership = HouseholdMembership(
        household_id=household.id,
        user_id=user.id,
        role='owner',
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(membership)
    db.commit()
    db.refresh(household)
    db.refresh(membership)
    return household, membership


def generate_invite_code(db: OrmSession, user: User) -> Household:
    household, _ = ensure_household_for_user(db, user)
    for _ in range(12):
        code = _generate_invite_code()
        exists = db.scalar(select(func.count(Household.id)).where(Household.invite_code == code)) or 0
        if not exists:
            household.invite_code = code
            household.invite_code_created_at = datetime.utcnow()
            household.updated_at = datetime.utcnow()
            db.add(household)
            db.commit()
            db.refresh(household)
            return household
    raise HouseholdError('INVITE_CODE_GENERATION_FAILED', '초대 코드를 만들지 못했어')


def join_household_by_invite_code(db: OrmSession, user: User, invite_code: str) -> Household:
    normalized = ''.join((invite_code or '').strip().upper().split())
    if not normalized:
        raise HouseholdError('INVITE_CODE_REQUIRED', '초대 코드를 입력해 줘')

    existing = get_membership(db, user.id)
    if existing is not None:
        raise HouseholdError('ALREADY_IN_HOUSEHOLD', '이미 가족 그룹에 참여 중이야')

    household = db.scalar(select(Household).where(Household.invite_code == normalized))
    if household is None:
        raise HouseholdError('INVITE_CODE_INVALID', '초대 코드를 찾지 못했어')

    membership = HouseholdMembership(
        household_id=household.id,
        user_id=user.id,
        role='member',
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(membership)
    household.updated_at = datetime.utcnow()
    db.add(household)
    db.commit()
    db.refresh(household)
    return household


def leave_household(db: OrmSession, user: User) -> None:
    membership = get_membership(db, user.id)
    if membership is None:
        raise HouseholdError('HOUSEHOLD_NOT_FOUND', '가족 그룹에 참여 중이 아니야')

    household = db.get(Household, membership.household_id)
    if household is None:
        db.delete(membership)
        db.commit()
        return

    member_rows = list(
        db.scalars(
            select(HouseholdMembership)
            .where(HouseholdMembership.household_id == household.id)
            .order_by(HouseholdMembership.created_at.asc())
        ).all()
    )

    if membership.role == 'owner':
        for row in member_rows:
            db.delete(row)
        db.delete(household)
        db.commit()
        return

    db.delete(membership)
    household.updated_at = datetime.utcnow()
    db.add(household)
    db.commit()


def serialize_household_state(db: OrmSession, user: User) -> dict:
    membership = get_membership(db, user.id)
    if membership is None:
        return {
            'hasHousehold': False,
            'household': None,
            'members': [],
            'me': None,
        }

    household = db.get(Household, membership.household_id)
    if household is None:
        return {
            'hasHousehold': False,
            'household': None,
            'members': [],
            'me': None,
        }

    memberships = list(
        db.scalars(
            select(HouseholdMembership)
            .where(HouseholdMembership.household_id == household.id)
            .order_by(HouseholdMembership.created_at.asc())
        ).all()
    )
    users = {
        member.id: member
        for member in db.scalars(select(User).where(User.id.in_([row.user_id for row in memberships]))).all()
    }
    members = []
    for row in memberships:
        member_user = users.get(row.user_id)
        if member_user is None:
            continue
        members.append(
            {
                'userId': member_user.id,
                'displayName': member_user.display_name,
                'email': member_user.email,
                'role': row.role,
                'joinedAt': row.created_at.isoformat() if row.created_at else None,
                'isMe': member_user.id == user.id,
            }
        )
    return {
        'hasHousehold': True,
        'household': {
            'id': household.id,
            'name': household.name,
            'inviteCode': household.invite_code,
            'inviteCodeCreatedAt': household.invite_code_created_at.isoformat() if household.invite_code_created_at else None,
            'memberCount': len(members),
            'createdByUserId': household.created_by_user_id,
        },
        'members': members,
        'me': {
            'userId': user.id,
            'role': membership.role,
        },
    }
