import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from .core.runtime_surface import runtime_surface_labels
from .core.storage_paths import ads_assets_dir, branding_assets_dir, runtime_assets_root
from .core.settings import settings
from .db.init_db import init_db
from .routers import admin, ads_runtime, auth, carts, config, events, explore, households, push, receipts, scan
from .services.admin_snapshot_scheduler import AdminDashboardSnapshotScheduler
from .services.push_scheduler import PushCampaignScheduler
from .services.storage_health import ensure_storage_ready, storage_health_check

snapshot_scheduler = AdminDashboardSnapshotScheduler()
push_scheduler = PushCampaignScheduler()


@asynccontextmanager
async def lifespan(_: FastAPI):
    await asyncio.to_thread(ensure_storage_ready)
    await asyncio.to_thread(init_db)
    await snapshot_scheduler.run_startup_catchup()
    await push_scheduler.run_startup_catchup()
    await snapshot_scheduler.start()
    await push_scheduler.start()
    try:
        yield
    finally:
        await push_scheduler.stop()
        await snapshot_scheduler.stop()


app = FastAPI(title='Cartly API', version='0.1.0', lifespan=lifespan)

app.mount('/assets/branding', StaticFiles(directory=str(branding_assets_dir())), name='branding-assets')
app.mount('/assets/ads', StaticFiles(directory=str(ads_assets_dir())), name='ads-assets')

app.include_router(auth.router, prefix='/v1/auth', tags=['auth'])
app.include_router(scan.router, prefix='/v1/scan', tags=['scan'])
app.include_router(carts.router, prefix='/v1/carts', tags=['carts'])
app.include_router(households.router, prefix='/v1/households', tags=['households'])
app.include_router(receipts.router, prefix='/v1/receipts', tags=['receipts'])
app.include_router(events.router, prefix='/v1/events', tags=['events'])
app.include_router(ads_runtime.router, prefix='/v1/ads', tags=['ads'])
app.include_router(explore.router, prefix='/v1/explore', tags=['explore'])
app.include_router(push.router, prefix='/v1/push', tags=['push'])
app.include_router(config.router, prefix='/v1', tags=['config'])
app.include_router(admin.router, prefix='/admin', tags=['admin'])


@app.get('/health')
def health():
    storage = storage_health_check(create_probe=False)
    surface = runtime_surface_labels()
    return {
        'ok': True,
        'service': 'cartly-api',
        'serviceName': surface['serviceName'],
        'storageRoot': settings.storage_root,
        'storageRootDisplay': surface['storageRootDisplay'],
        'storageRootActual': surface['storageRootActual'],
        'storageWritable': storage['writable'],
        'storagePaths': storage['paths'],
        'storageErrors': storage['errors'],
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
        'remoteScanEnabled': settings.remote_scan_enabled,
        'adsEnabled': settings.ads_enabled,
    }
