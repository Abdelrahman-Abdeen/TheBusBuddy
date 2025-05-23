from dataclasses import dataclass, field
from src.domain.entities.base_entity import BaseEntity
from src.domain.value_objects.location import Location
from src.domain.enums.route_preference import RoutePreference


@dataclass
class Student(BaseEntity):
    first_name: str
    last_name: str
    phone_number: str
    id: int | None = None
    current_status: str | None = None
    home_location: Location | None = None
    bus_id : int | None = None
    route_preference: RoutePreference | None = None
    events: list[int] = field(default_factory=list)
    parents: list[int] = field(default_factory=list)
    images: list[str] = field(default_factory=list)
