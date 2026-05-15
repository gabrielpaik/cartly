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


class AdminPushAudienceEntry(BaseModel):
    userId: Optional[str] = None
    installId: Optional[str] = None
    name: Optional[str] = None
    memo: Optional[str] = None


class AdminPushAudiencePreviewRequest(BaseModel):
    entries: list[AdminPushAudienceEntry] = []


class AdminPushRegionSegment(BaseModel):
    mode: Literal['none', 'recent', 'frequent', 'primary'] = 'none'
    regionKeys: list[str] = []
    recentWithinDays: Optional[int] = None
    minVisits: Optional[int] = None


class AdminPushSegmentPreviewRequest(BaseModel):
    audience: Literal['all', 'members', 'guests'] = 'all'
    segment: Optional[AdminPushRegionSegment] = None


class AdminPushBroadcastRequest(BaseModel):
    kind: Literal['notice', 'promotion'] = 'notice'
    audience: Literal['all', 'members', 'guests', 'upload'] = 'all'
    title: str
    message: str
    targetTab: Optional[Literal['home', 'explore', 'my']] = None
    targetUrl: Optional[str] = None
    explicitAudience: Optional[list[AdminPushAudienceEntry]] = None
    segment: Optional[AdminPushRegionSegment] = None
