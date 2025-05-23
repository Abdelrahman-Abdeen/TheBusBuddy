
from dataclasses import dataclass, field
from src.domain.entities.base_entity import BaseEntity
from src.domain.value_objects.location import Location
from src.domain.enums.route_mode import RouteMode

@dataclass
class Bus(BaseEntity):
    id: int

    is_monitoring_enabled: bool
    driver_name: str | None = None
    driver_phone: str | None = None
    admin_id: int| None = None
    events: list[int] = field(default_factory=list)
    route_mode: RouteMode | None = None
    # gps_tracker_id: int
    # camera_id: int
    currently_in_bus_students: list[int] = field(default_factory=list)
    registered_students: list[int] = field(default_factory=list)
    location: Location| None = None
