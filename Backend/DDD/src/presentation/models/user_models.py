from pydantic import BaseModel


class CreateParentRequest(BaseModel):
    phone_number: str
    first_name: str
    last_name: str
    email: str
    password: str


class UpdateParentRequest(BaseModel):
    phone_number: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    email: str | None = None
    device_token: str | None = None
    is_notified_arrival: bool = False
    is_notified_approach: bool = False

class LoginRequest(BaseModel):
    phone_number: str
    password: str

class CreateAdminRequest(BaseModel):
    phone_number: str
    first_name: str
    last_name: str
    email: str
    password: str


class NotificationCreateRequest(BaseModel):
    title: str
    message: str
    recipient_ids: list[int]


class DeviceTokenUpdateRequest(BaseModel):
    device_token: str



