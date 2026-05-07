from typing import List, Optional

from pydantic import BaseModel


class CartItemRequest(BaseModel):
    name: str
    price: int
    quantity: int = 1
    scanResultId: Optional[str] = None
    originalName: Optional[str] = None


class CreateCartRequest(BaseModel):
    title: Optional[str] = None
    items: List[CartItemRequest]


class UpdateCartRequest(BaseModel):
    title: Optional[str] = None
    items: Optional[List[CartItemRequest]] = None
