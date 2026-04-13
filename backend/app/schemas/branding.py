from typing import Optional

from pydantic import BaseModel


class BrandingRequest(BaseModel):
    logoType: str = 'text'
    logoText: str = 'Cartly'
    logoImageUrl: Optional[str] = None
    splashImageUrl: Optional[str] = None
    loginHeroImageUrl: Optional[str] = None
    homeTabLabel: str = 'Home'
    helpTabLabel: str = '도움'
    myTabLabel: str = 'My'
