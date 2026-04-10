from fastapi import APIRouter

from . import admin_ads, admin_carts, admin_config, admin_content, admin_dashboard, admin_scan_ops, admin_session, admin_users

router = APIRouter()
router.include_router(admin_session.router)
router.include_router(admin_dashboard.router)
router.include_router(admin_users.router)
router.include_router(admin_scan_ops.router)
router.include_router(admin_carts.router)
router.include_router(admin_ads.router)
router.include_router(admin_content.router)
router.include_router(admin_config.router)
