from src.domain.entities.base_entity import BaseEntity
from dataclasses import dataclass
from datetime import datetime
from src.domain.enums.event_type import EventType
from src.domain.value_objects.location import Location


@dataclass
class Event(BaseEntity):
    event_type: EventType
    time: datetime
    location: Location
    bus_id: int
    id: int | None = None
    student_id: int | None = None
