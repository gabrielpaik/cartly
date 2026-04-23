from typing import Literal, Optional

from pydantic import BaseModel


ReceiptStatus = Literal['processing', 'ready', 'failed']
ReceiptLineItemCategory = Literal['item', 'discount', 'coupon', 'subtotal', 'tax', 'payment']


class ReceiptSummary(BaseModel):
    id: str
    savedCartId: str
    status: ReceiptStatus
    imageUrl: Optional[str] = None
    merchantName: Optional[str] = None
    purchasedAt: Optional[str] = None
    currency: str = 'KRW'
    subtotal: Optional[int] = None
    tax: Optional[int] = None
    totalAmount: Optional[int] = None
    totalDiscountAmount: Optional[int] = None
    errorMessage: Optional[str] = None
    createdAt: Optional[str] = None
    updatedAt: Optional[str] = None


class ReceiptLineItemPayload(BaseModel):
    id: str
    rawName: str
    normalizedName: str
    quantity: Optional[int] = None
    unitPrice: Optional[int] = None
    lineAmount: int
    finalAmount: Optional[int] = None
    category: ReceiptLineItemCategory = 'item'
    confidence: Optional[float] = None


class ReceiptResultPayload(BaseModel):
    receipt: ReceiptSummary
    lineItems: list[ReceiptLineItemPayload]
