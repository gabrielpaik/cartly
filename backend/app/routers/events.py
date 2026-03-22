import json

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppEvent
from ..deps import current_user_dep, db_dep
from ..schemas.event import EventsRequest

router = APIRouter()


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
        )
        db.add(row)
        count += 1
    db.commit()
    return {'ok': True, 'data': {'accepted': count}}
