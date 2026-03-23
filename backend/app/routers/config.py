from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..deps import db_dep
from ..services.branding_service import get_branding

router = APIRouter()


@router.get('/app-config')
def app_config(db: OrmSession = Depends(db_dep)):
    return {
        'ok': True,
        'data': {
            'features': {
                'remoteScan': settings.remote_scan_enabled,
                'adsEnabled': settings.ads_enabled,
            },
            'branding': get_branding(db),
            'adSlots': [
                {
                    'slotKey': 'save_complete_sheet_1',
                    'placementType': 'bottom_sheet',
                    'enabled': settings.ads_enabled,
                    'config': {
                        'maxHeight': 88,
                        'screen': 'save_complete',
                        'position': 'after_summary_before_actions',
                        'tone': 'benefit_native',
                    },
                },
                {
                    'slotKey': 'saved_inline_1',
                    'placementType': 'inline',
                    'enabled': settings.ads_enabled,
                    'config': {
                        'maxHeight': 104,
                        'screen': 'saved_list',
                        'position': 'after_first_card',
                        'tone': 'benefit_native',
                    },
                },
                {
                    'slotKey': 'saved_inline_2',
                    'placementType': 'inline',
                    'enabled': settings.ads_enabled,
                    'config': {
                        'maxHeight': 104,
                        'screen': 'saved_list',
                        'position': 'after_third_card',
                        'tone': 'benefit_native',
                    },
                },
                {
                    'slotKey': 'my_perks_inline_1',
                    'placementType': 'inline',
                    'enabled': settings.ads_enabled,
                    'config': {
                        'maxHeight': 96,
                        'screen': 'my',
                        'position': 'below_account_card',
                        'tone': 'soft_promo',
                    },
                },
            ],
        },
    }
