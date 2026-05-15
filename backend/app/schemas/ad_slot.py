from typing import Optional

from pydantic import BaseModel


class AdSlotUpdateRequest(BaseModel):
    status: Optional[str] = None
    slotLabel: Optional[str] = None
    slotDescription: Optional[str] = None
    placementNote: Optional[str] = None


class AdCampaignUpsertRequest(BaseModel):
    slotKey: str
    title: Optional[str] = None
    message: Optional[str] = None
    ctaLabel: Optional[str] = None
    targetUrl: Optional[str] = None
    imageUrl: Optional[str] = None
    startAt: Optional[str] = None
    endAt: Optional[str] = None
