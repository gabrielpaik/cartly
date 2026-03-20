from fastapi import APIRouter

router = APIRouter()


@router.get('/app-config')
def app_config():
    return {
        'ok': True,
        'data': {
            'features': {
                'remoteScan': True,
                'adsEnabled': True,
            },
            'adSlots': [
                {
                    'slotKey': 'result_inline_1',
                    'placementType': 'inline',
                    'enabled': True,
                    'config': {'maxHeight': 96},
                }
            ],
        },
    }
