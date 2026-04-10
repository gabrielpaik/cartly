from typing import Optional

from pydantic import BaseModel


class AdImpressionRequest(BaseModel):
    slotKey: str
    campaignId: str
    screenName: Optional[str] = None
    creativeId: Optional[str] = None


class AdClickRequest(BaseModel):
    impressionId: str
