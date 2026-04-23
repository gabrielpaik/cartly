from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..core.runtime_surface import runtime_surface_labels
from ..core.settings import settings
from ..core.storage_paths import ads_assets_dir, branding_assets_dir, runtime_assets_root
from ..deps import db_dep
from ..services.branding_service import get_branding
from ..services.storage_health import storage_health_check
from .admin_common import ADMIN_ROUTE_DEP

router = APIRouter(dependencies=ADMIN_ROUTE_DEP)


@router.get('/config')
def admin_config(db: OrmSession = Depends(db_dep)):
    storage = storage_health_check(create_probe=False)
    surface = runtime_surface_labels()
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
        },
    }
