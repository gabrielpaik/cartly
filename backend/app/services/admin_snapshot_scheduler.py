import asyncio
import logging
from contextlib import suppress
from typing import Optional

from ..db.session import SessionLocal
from .admin_service import ensure_today_dashboard_snapshot, refresh_dashboard_summary_snapshot, seconds_until_next_dashboard_snapshot

logger = logging.getLogger(__name__)


class AdminDashboardSnapshotScheduler:
    def __init__(self) -> None:
        self._task: Optional[asyncio.Task] = None

    async def start(self) -> None:
        if self._task and not self._task.done():
            return
        self._task = asyncio.create_task(self._run_loop(), name='cartly-admin-dashboard-snapshot-scheduler')

    async def stop(self) -> None:
        if self._task is None:
            return
        self._task.cancel()
        with suppress(asyncio.CancelledError):
            await self._task
        self._task = None

    async def run_startup_catchup(self) -> None:
        await asyncio.to_thread(self._ensure_today_snapshot_if_due)

    def _ensure_today_snapshot_if_due(self) -> None:
        db = SessionLocal()
        try:
            ensure_today_dashboard_snapshot(db)
        except Exception:
            logger.exception('Failed to ensure today dashboard snapshot during startup catch-up')
        finally:
            db.close()

    def _run_scheduled_snapshot(self) -> None:
        db = SessionLocal()
        try:
            refresh_dashboard_summary_snapshot(db, source='scheduled')
        except Exception:
            logger.exception('Failed to refresh scheduled dashboard snapshot')
        finally:
            db.close()

    async def _run_loop(self) -> None:
        while True:
            await asyncio.sleep(seconds_until_next_dashboard_snapshot())
            await asyncio.to_thread(self._run_scheduled_snapshot)
