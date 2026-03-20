from pydantic import BaseModel


class ErrorDetail(BaseModel):
    code: str
    message: str


class OkResponse(BaseModel):
    ok: bool = True
    data: dict


class ErrorResponse(BaseModel):
    ok: bool = False
    error: ErrorDetail
