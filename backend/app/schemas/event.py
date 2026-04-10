from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class EventDto(BaseModel):
    name: str
    screen: Optional[str] = None
    props: Dict[str, Any] = Field(default_factory=dict)
    clientTimestamp: Optional[str] = None
    devicePlatform: Optional[str] = None
    deviceType: Optional[str] = None
    osName: Optional[str] = None
    osVersion: Optional[str] = None
    appVersion: Optional[str] = None


class EventsRequest(BaseModel):
    events: List[EventDto]


class DashboardSummaryDto(BaseModel):
    dau: int
    wau: int
    mau: int
    activeUsers: int
    newUsers: int
    guestToMemberConversion: float
    totalScans: int
    scanSuccessRate: float
    cartSaveRate: float
    adImpressions: int
    adClicks: int
    adCtr: float
