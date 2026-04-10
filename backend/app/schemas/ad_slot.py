from typing import Optional

from pydantic import BaseModel


class AdSlotUpdateRequest(BaseModel):
    status: Optional[str] = None
    slotLabel: Optional[str] = None
    slotDescription: Optional[str] = None
    placementNote: Optional[str] = None
    title: Optional[str] = None
    message: Optional[str] = None
    ctaLabel: Optional[str] = None
    targetUrl: Optional[str] = None
    imageUrl: Optional[str] = None
    reservedTitle: Optional[str] = None
    reservedMessage: Optional[str] = None
    reservedCtaLabel: Optional[str] = None
    reservedTargetUrl: Optional[str] = None
    reservedImageUrl: Optional[str] = None
    exposureStartAt: Optional[str] = None
    exposureEndAt: Optional[str] = None
    reservationStartAt: Optional[str] = None
    reservationEndAt: Optional[str] = None
