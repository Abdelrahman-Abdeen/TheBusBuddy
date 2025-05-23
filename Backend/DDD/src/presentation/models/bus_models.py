from pydantic import BaseModel
from src.domain.enums.route_mode import RouteMode

class LocationRequest(BaseModel):
    latitude: float
    longitude: float

class BusCreateRequest(BaseModel):
    id:int
    driver_name: str
    driver_phone: str
    is_monitoring_enabled: bool = False
    admin_id: int| None = None
    # gps_tracker_id: int
    # camera_id: int

class BusUpdateRequest(BaseModel):
    driver_name: str | None = None
    driver_phone: str | None = None
    is_monitoring_enabled: bool | None = None
    admin_id: int| None = None
    route_mode: RouteMode | None = None

class AssignBusesRequest(BaseModel):
    bus_ids: list[int]