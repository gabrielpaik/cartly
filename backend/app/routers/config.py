from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..deps import db_dep
from ..services.ad_slot_service import app_ad_slots_config
from ..services.app_copy_service import get_app_copy
from ..services.branding_service import get_branding

router = APIRouter()


@router.get('/app-config')
def app_config(db: OrmSession = Depends(db_dep)):
    branding = get_branding(db)
    ad_slots = app_ad_slots_config(db, settings.ads_enabled)
    copy = get_app_copy(db, branding)
    return {
        'ok': True,
        'data': {
            'version': 1,
            'generatedAt': datetime.now(timezone.utc).isoformat(),
            'features': {
                'remoteScan': settings.remote_scan_enabled,
                'adsEnabled': settings.ads_enabled,
                'manualAddEnabled': True,
                'guestModeEnabled': True,
                'savedCartEditingEnabled': True,
                'emailSignupEnabled': True,
                'kakaoEnabled': True,
                'googleEnabled': True,
            },
            'branding': {
                'logoType': branding.get('logoType'),
                'logoText': branding.get('logoText'),
                'logoImageUrl': branding.get('logoImageUrl'),
                'splashImageUrl': branding.get('splashImageUrl'),
                'loginHeroImageUrl': branding.get('loginHeroImageUrl'),
                'tabs': {
                    'home': branding.get('homeTabLabel'),
                    'saved': branding.get('savedTabLabel'),
                    'my': branding.get('myTabLabel'),
                },
                **branding,
            },
            'copy': copy,
            'ads': {
                'slots': ad_slots,
            },
            'adSlots': ad_slots,
        },
    }
