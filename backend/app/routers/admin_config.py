from typing import Any, Dict

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..core.runtime_surface import runtime_surface_labels
from ..core.settings import settings
from ..core.storage_paths import ads_assets_dir, branding_assets_dir, runtime_assets_root
from ..deps import db_dep
from ..services.branding_service import get_branding
from ..services.coupang_runtime_service import get_coupang_runtime_status, save_coupang_runtime
from ..services.push_service import get_push_runtime_status
from ..services.runtime_settings_service import get_runtime_settings, save_runtime_settings
from ..services.smoke_history_service import get_smoke_history, record_smoke_result
from ..services.storage_health import storage_health_check
from .admin_common import ADMIN_ROUTE_DEP

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/config')
def admin_config(db: OrmSession = Depends(db_dep)):
    storage = storage_health_check(create_probe=False)
    surface = runtime_surface_labels()
    coupang_runtime = get_coupang_runtime_status(db)
    smoke_history = get_smoke_history(db)
    return {
        'ok': True,
        'data': {
            'remoteScan': settings.remote_scan_enabled,
            'adsEnabled': settings.ads_enabled,
            'serviceName': surface['serviceName'],
            'storageRoot': settings.storage_root,
            'storageRootDisplay': surface['storageRootDisplay'],
            'storageRootActual': surface['storageRootActual'],
            'storageWritable': storage['writable'],
            'storagePaths': storage['paths'],
            'storageErrors': storage['errors'],
            'backendRunMode': 'terminal-login-session-supervised',
            'runtimeAssetsRoot': str(runtime_assets_root()),
            'runtimeAssetsRootDisplay': surface['runtimeAssetsRootDisplay'],
            'runtimeAssetsRootActual': surface['runtimeAssetsRootActual'],
            'brandingAssetsDir': str(branding_assets_dir()),
            'brandingAssetsDirDisplay': surface['brandingAssetsDirDisplay'],
            'brandingAssetsDirActual': surface['brandingAssetsDirActual'],
            'adsAssetsDir': str(ads_assets_dir()),
            'adsAssetsDirDisplay': surface['adsAssetsDirDisplay'],
            'adsAssetsDirActual': surface['adsAssetsDirActual'],
            'legacyPathCompatibilityActive': surface['legacyPathCompatibilityActive'],
            'apiBase': settings.api_base_url,
            'branding': get_branding(db),
            'publicSite': {
                'dynamicLandingEnabled': True,
                'landingRoutes': ['/', '/partners'],
                'privacyRoutes': ['/privacy'],
                'assetsRoutePrefix': '/assets/branding',
            },
            'coupangPartners': coupang_runtime,
            'push': get_push_runtime_status(db),
            'runtimeSettings': get_runtime_settings(db),
            'smokeHistory': smoke_history.get('history') or [],
        },
    }


@router.put('/config/coupang-partners')
def update_coupang_partners_config(payload: Dict[str, Any], db: OrmSession = Depends(db_dep)):
    save_coupang_runtime(db, payload)
    return {
        'ok': True,
        'data': get_coupang_runtime_status(db),
    }


@router.put('/config/runtime-settings')
def update_runtime_settings(payload: Dict[str, Any], db: OrmSession = Depends(db_dep)):
    return {
        'ok': True,
        'data': save_runtime_settings(db, payload),
    }


@router.post('/config/smoke-history')
def append_smoke_history(payload: Dict[str, Any], db: OrmSession = Depends(db_dep)):
    history = record_smoke_result(db, payload)
    return {
        'ok': True,
        'data': history,
    }
