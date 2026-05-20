import asyncio
import logging
from contextlib import suppress
from typing import Optional

from ..db.session import SessionLocal
from .push_service import dispatch_due_push_schedule

logger = logging.getLogger(__name__)
PUSH_SCHEDULE_CHECK_SECONDS = 30


class PushCampaignScheduler:
    def __init__(self) -> None:
        self._task: Optional[asyncio.Task] = None

    async def start(self) -> None:
        if self._task and not self._task.done():
            return
        self._task = asyncio.create_task(self._run_loop(), name='cartly-push-campaign-scheduler')

    async def stop(self) -> None:
        if self._task is None:
            return
        self._task.cancel()
        with suppress(asyncio.CancelledError):
            await self._task
        self._task = None

    async def run_startup_catchup(self) -> None:
        await asyncio.to_thread(self._dispatch_due_schedule)

    def _dispatch_due_schedule(self) -> None:
        db = SessionLocal()
        try:
            result = dispatch_due_push_schedule(db)
            if result and result.get('lastDispatchCampaignId'):
                logger.info('Dispatched recurring push schedule campaign=%s status=%s', result.get('lastDispatchCampaignId'), result.get('lastDispatchStatus'))
        except Exception:
            logger.exception('Failed to dispatch recurring push schedule')
        finally:
            db.close()

    async def _run_loop(self) -> None:
        while True:
            await asyncio.sleep(PUSH_SCHEDULE_CHECK_SECONDS)
            await asyncio.to_thread(self._dispatch_due_schedule)
