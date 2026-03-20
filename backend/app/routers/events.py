from fastapi import APIRouter

from ..schemas.event import EventsRequest

router = APIRouter()


@router.post('')
def ingest_events(payload: EventsRequest):
    return {'ok': True, 'data': {'accepted': len(payload.events)}}
