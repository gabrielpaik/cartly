from pydantic import BaseModel


class CartItemRequest(BaseModel):
    name: str
    price: int
    quantity: int = 1
    scanResultId: str | None = None


class CreateCartRequest(BaseModel):
    title: str | None = None
    items: list[CartItemRequest]
