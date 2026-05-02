from typing import Any, Dict, Literal, Optional

from pydantic import BaseModel


class PushDeviceRegisterRequest(BaseModel):
    installId: str
    platform: str
    pushProvider: Optional[str] = None
    pushToken: Optional[str] = None
    notificationsEnabled: bool = False
    appVersion: Optional[str] = None
    locale: Optional[str] = None
    debugInfo: Optional[Dict[str, Any]] = None


class AdminPushBroadcastRequest(BaseModel):
    kind: Literal['notice', 'promotion'] = 'notice'
    audience: Literal['all', 'members', 'guests'] = 'all'
    title: str
    message: str
    targetTab: Optional[Literal['home', 'explore', 'my']] = None
    targetUrl: Optional[str] = None
