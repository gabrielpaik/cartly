from fastapi import APIRouter

from ..core.settings import settings

router = APIRouter()


@router.get('/app-config')
def app_config():
    return {
        'ok': True,
        'data': {
            'features': {
                'remoteScan': settings.remote_scan_enabled,
                'adsEnabled': settings.ads_enabled,
            },
            'adSlots': [
                {
                    'slotKey': 'result_inline_1',
                    'placementType': 'inline',
                    'enabled': settings.ads_enabled,
                    'config': {'maxHeight': 96},
                }
            ],
        },
    }
