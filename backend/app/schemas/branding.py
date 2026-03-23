from typing import Optional

from pydantic import BaseModel


class BrandingRequest(BaseModel):
    logoType: str = 'text'
    logoText: str = "What's in my cart"
    logoImageUrl: Optional[str] = None
    homeSubtitle: str = '지금 카트 총액을 확인해'
    savedSubtitle: str = '저장한 카트를 다시 봐'
    mySubtitle: str = '기록을 남기려면 로그인'
    loginSubtitle: str = '저장과 기록을 이어가려면 로그인'
    saveCompleteTitle: str = '카트 저장 완료'
    saveCompleteSubtitle: str = '다음 장보기 전에 다시 볼 수 있어'
