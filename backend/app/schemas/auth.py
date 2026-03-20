from pydantic import BaseModel, EmailStr


class GuestLoginRequest(BaseModel):
    deviceId: str | None = None
    platform: str | None = None
    appVersion: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    displayName: str
    deviceId: str | None = None
