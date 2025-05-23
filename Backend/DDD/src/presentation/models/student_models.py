from pydantic import BaseModel
from src.domain.enums.route_preference import RoutePreference

class StudentCreateRequest(BaseModel):
    first_name: str
    last_name: str
    phone_number: str
    bus_id: int | None = None
    route_preference: RoutePreference = RoutePreference.BOTH


class StudentUpdateRequest(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    phone_number: str | None = None
    bus_id: int | None = None
    home_latitude: float | None = None
    home_longitude: float | None = None
    route_preference: RoutePreference | None = None

class ParentIdsRequest(BaseModel):
    parent_ids: list[int]

class StudentIdsRequest(BaseModel):
    student_ids: list[int]