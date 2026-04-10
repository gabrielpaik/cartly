import json
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppEvent
from ..deps import current_user_dep, db_dep
from ..schemas.event import EventsRequest

router = APIRouter()


def _parse_client_timestamp(value: Optional[str]):
    if not value:
        return None
    try:
        normalized = value.replace('Z', '+00:00')
        parsed = datetime.fromisoformat(normalized)
        if parsed.tzinfo is not None:
            return parsed.astimezone(timezone.utc).replace(tzinfo=None)
        return parsed
    except ValueError:
        return None


@router.post('')
def ingest_events(
    payload: EventsRequest,
    db: OrmSession = Depends(db_dep),
    current_user=Depends(current_user_dep),
):
    count = 0
    for event in payload.events:
        row = AppEvent(
            user_id=getattr(current_user, 'id', None),
            session_id=None,
            event_name=event.name,
            screen_name=event.screen,
            event_props_json=json.dumps(event.props, ensure_ascii=False) if event.props else None,
            client_timestamp=_parse_client_timestamp(event.clientTimestamp),
            device_platform=event.devicePlatform,
            device_type=event.deviceType,
            os_name=event.osName,
            os_version=event.osVersion,
            app_version=event.appVersion,
        )
        db.add(row)
        count += 1
    db.commit()
    return {'ok': True, 'data': {'accepted': count}}
