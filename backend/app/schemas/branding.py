from typing import Optional

from pydantic import BaseModel


class BrandingRequest(BaseModel):
    logoType: str = 'image'
    logoText: str = 'Cartly'
    logoImageUrl: Optional[str] = 'https://scan-api.seoa-nas.com/assets/branding/cartly_logo_vectorized.svg'
    splashImageUrl: Optional[str] = 'https://scan-api.seoa-nas.com/assets/branding/cartly_splash_default.png'
    loginHeroImageUrl: Optional[str] = None
    homeTabLabel: str = 'Home'
    helpTabLabel: str = '탐색'
    myTabLabel: str = 'My'
