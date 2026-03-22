from typing import Any, Dict, Optional

from pydantic import BaseModel


class ScanJobDto(BaseModel):
    id: str
    status: str
    createdAt: Optional[str] = None
    updatedAt: Optional[str] = None
    errorCode: Optional[str] = None
    errorMessage: Optional[str] = None


class ScanResultDto(BaseModel):
    name: str
    price: int
    sku: Optional[str] = None
    confidence: Optional[float] = None
    source: str
    rawText: Optional[str] = None


class ScanFeedbackRequest(BaseModel):
    accepted: bool
    original: Optional[Dict[str, Any]] = None
    corrected: Optional[Dict[str, Any]] = None


class ScanFailureRequest(BaseModel):
    stage: str = 'processing'
    errorCode: Optional[str] = None
    errorMessage: Optional[str] = None
    details: Optional[Dict[str, Any]] = None
