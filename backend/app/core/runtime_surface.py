from pathlib import Path
from typing import Any, Dict, Union

from .settings import settings
from .storage_paths import ads_assets_dir, branding_assets_dir, runtime_assets_root


def _cartly_display_path(value: Union[str, Path]) -> str:
    path = str(value)
    return path.replace('/WIMC', '/Cartly').replace('Application Support/WIMC', 'Application Support/Cartly')


def runtime_surface_labels() -> Dict[str, Any]:
    storage_root_actual = settings.storage_root
    runtime_assets_actual = str(runtime_assets_root())
    branding_assets_actual = str(branding_assets_dir())
    ads_assets_actual = str(ads_assets_dir())

    storage_root_display = _cartly_display_path(storage_root_actual)
    runtime_assets_display = _cartly_display_path(runtime_assets_actual)
    branding_assets_display = _cartly_display_path(branding_assets_actual)
    ads_assets_display = _cartly_display_path(ads_assets_actual)

    return {
        'serviceName': settings.app_name,
        'storageRootDisplay': storage_root_display,
        'storageRootActual': storage_root_actual,
        'runtimeAssetsRootDisplay': runtime_assets_display,
        'runtimeAssetsRootActual': runtime_assets_actual,
        'brandingAssetsDirDisplay': branding_assets_display,
        'brandingAssetsDirActual': branding_assets_actual,
        'adsAssetsDirDisplay': ads_assets_display,
        'adsAssetsDirActual': ads_assets_actual,
        'legacyPathCompatibilityActive': any(
            display != actual
            for display, actual in [
                (storage_root_display, storage_root_actual),
                (runtime_assets_display, runtime_assets_actual),
                (branding_assets_display, branding_assets_actual),
                (ads_assets_display, ads_assets_actual),
            ]
        ),
    }
