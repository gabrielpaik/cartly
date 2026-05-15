from typing import Any, Dict, Optional

from pydantic import BaseModel


class AdSlotUpdateRequest(BaseModel):
    status: Optional[str] = None
    slotLabel: Optional[str] = None
    slotDescription: Optional[str] = None
    placementNote: Optional[str] = None


class AdCampaignUpsertRequest(BaseModel):
    slotKey: str
    sortOrder: Optional[int] = None
    title: Optional[str] = None
    message: Optional[str] = None
    ctaLabel: Optional[str] = None
    targetUrl: Optional[str] = None
    landingType: Optional[str] = None
    landingKey: Optional[str] = None
    landingParams: Optional[Dict[str, Any]] = None
    imageUrl: Optional[str] = None
    audienceType: Optional[str] = None
    targetRegionLevel: Optional[str] = None
    targetCity: Optional[str] = None
    targetDistrict: Optional[str] = None
    targetNeighborhood: Optional[str] = None
    targetRegionKeys: Optional[list[str]] = None
    startAt: Optional[str] = None
    endAt: Optional[str] = None
