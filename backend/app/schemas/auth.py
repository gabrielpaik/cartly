from typing import Literal, Optional

from pydantic import BaseModel, EmailStr


AuthProvider = Literal['email', 'google', 'kakao']


class GuestLoginRequest(BaseModel):
    deviceId: Optional[str] = None
    platform: Optional[str] = None
    appVersion: Optional[str] = None


class LoginRequest(BaseModel):
    email: EmailStr
    displayName: str
    provider: AuthProvider = 'email'
    deviceId: Optional[str] = None
