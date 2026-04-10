from pathlib import Path

from .settings import settings


def runtime_assets_root() -> Path:
    target = Path(settings.runtime_assets_root).expanduser()
    target.mkdir(parents=True, exist_ok=True)
    return target


def branding_assets_dir() -> Path:
    target = runtime_assets_root() / 'branding'
    target.mkdir(parents=True, exist_ok=True)
    return target


def ads_assets_dir() -> Path:
    target = runtime_assets_root() / 'ads'
    target.mkdir(parents=True, exist_ok=True)
    return target
