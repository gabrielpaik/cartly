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


class AdminPushScheduleRequest(BaseModel):
    enabled: bool = False
    weekday: Literal['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] = 'fri'
    time: str = '18:30'
    timezone: str = 'Asia/Seoul'
    kind: Literal['notice', 'promotion'] = 'promotion'
    audience: Literal['all', 'members', 'guests'] = 'all'
    title: str = '이번 주말 장보기'
    message: str = '이번주말 카트리로 쇼핑 어때요?'
    targetTab: Optional[Literal['home', 'explore', 'my']] = 'home'
    targetUrl: Optional[str] = None
    segment: Optional[AdminPushRegionSegment] = None
