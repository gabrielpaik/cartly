from datetime import datetime, timezone
from typing import Optional
from urllib.parse import unquote

from fastapi import APIRouter, Depends, Header
from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..deps import current_user_dep, db_dep
from ..services.ad_slot_service import app_ad_slots_config, sync_user_region_context
from ..services.app_copy_service import get_app_copy
from ..services.branding_service import get_branding, project_branding
from ..services.content_settings_service import apply_due_content_schedule
from ..services.coupang_runtime_service import get_coupang_runtime_status
from ..services.explore_admin_service import get_explore_settings
from ..services.push_service import get_push_runtime_status
from ..services.runtime_settings_service import get_runtime_settings

router = APIRouter()


@router.get('/app-config')
def app_config(
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
    x_cartly_city: Optional[str] = Header(default=None),
    x_cartly_district: Optional[str] = Header(default=None),
    x_cartly_neighborhood: Optional[str] = Header(default=None),
    x_cartly_region_captured_at: Optional[str] = Header(default=None),
):
    apply_due_content_schedule(db)
    captured_at = None
    if x_cartly_region_captured_at:
        try:
            captured_at = datetime.fromisoformat(x_cartly_region_captured_at.strip())
        except ValueError:
            captured_at = None
    decoded_city = unquote(x_cartly_city.strip()) if x_cartly_city else None
    decoded_district = unquote(x_cartly_district.strip()) if x_cartly_district else None
    decoded_neighborhood = unquote(x_cartly_neighborhood.strip()) if x_cartly_neighborhood else None
    sync_user_region_context(
        db,
        current_user,
        city=decoded_city,
        district=decoded_district,
        neighborhood=decoded_neighborhood,
        captured_at=captured_at,
    )
    if current_user is not None and any([decoded_city, decoded_district, decoded_neighborhood]):
        db.commit()
        db.refresh(current_user)
    raw_branding = get_branding(db)
    branding = project_branding(raw_branding)
    ad_slots = app_ad_slots_config(
        db,
        settings.ads_enabled,
        current_user=current_user,
        city=decoded_city,
        district=decoded_district,
        neighborhood=decoded_neighborhood,
    )
    copy = get_app_copy(db, raw_branding)
    coupang_runtime = get_coupang_runtime_status(db)
    push_runtime = get_push_runtime_status(db)
    explore_settings = get_explore_settings(db)
    runtime_settings = get_runtime_settings(db)
    return {
        'ok': True,
        'data': {
            'version': 1,
            'generatedAt': datetime.now(timezone.utc).isoformat(),
            'features': {
                'remoteScan': settings.remote_scan_enabled,
                'adsEnabled': settings.ads_enabled,
                'exploreOfferBridgeEnabled': True,
                'coupangPartnersEnabled': coupang_runtime['enabled'],
                'coupangPartnersAffiliateReady': coupang_runtime['affiliateReady'],
                'remotePushEnabled': push_runtime['enabled'],
                'remotePushReady': push_runtime['ready'],
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
                    'help': branding.get('helpTabLabel') or '도움',
                    'my': branding.get('myTabLabel'),
                },
            },
            'copy': copy,
            'ads': {
                'slots': ad_slots,
            },
            'adSlots': ad_slots,
            'push': push_runtime,
            'explore': explore_settings,
            'runtime': runtime_settings,
        },
    }
