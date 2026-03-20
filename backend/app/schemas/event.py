from pydantic import BaseModel


class EventDto(BaseModel):
    name: str
    screen: str | None = None
    props: dict = {}
    clientTimestamp: str | None = None


class EventsRequest(BaseModel):
    events: list[EventDto]
