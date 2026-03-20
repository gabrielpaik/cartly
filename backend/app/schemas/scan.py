from pydantic import BaseModel


class ScanJobDto(BaseModel):
    id: str
    status: str
    createdAt: str | None = None
    updatedAt: str | None = None
    errorCode: str | None = None
    errorMessage: str | None = None


class ScanResultDto(BaseModel):
    name: str
    price: int
    sku: str | None = None
    confidence: float | None = None
    source: str
    rawText: str | None = None


class ScanFeedbackRequest(BaseModel):
    accepted: bool
    original: dict | None = None
    corrected: dict | None = None
