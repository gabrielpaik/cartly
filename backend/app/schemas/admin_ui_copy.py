from typing import Dict

from pydantic import BaseModel


class AdminUiCopyUpdateRequest(BaseModel):
    values: Dict[str, str]
