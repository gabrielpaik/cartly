from typing import List, Optional

from pydantic import BaseModel


class CartItemRequest(BaseModel):
    name: str
    price: int
    originalPrice: Optional[int] = None
    quantity: int = 1
    scanResultId: Optional[str] = None
    originalName: Optional[str] = None
    categoryLabel: Optional[str] = None
    categorySource: Optional[str] = None


class CreateCartRequest(BaseModel):
    title: Optional[str] = None
    items: List[CartItemRequest]
    shareWithHousehold: bool = False


class UpdateCartRequest(BaseModel):
    title: Optional[str] = None
    items: Optional[List[CartItemRequest]] = None
    shareWithHousehold: Optional[bool] = None


class ToggleCartHouseholdShareRequest(BaseModel):
    shareWithHousehold: bool
