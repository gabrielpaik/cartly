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


class EmailCodeRequest(BaseModel):
    email: EmailStr


class EmailCodeVerifyRequest(BaseModel):
    email: EmailStr
    code: str


class EmailRegisterRequest(BaseModel):
    email: EmailStr
    displayName: str
    password: str
    code: str
    deviceId: Optional[str] = None


class PasswordLoginRequest(BaseModel):
    email: EmailStr
    password: str
    deviceId: Optional[str] = None


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetConfirmRequest(BaseModel):
    email: EmailStr
    code: str
    newPassword: str
