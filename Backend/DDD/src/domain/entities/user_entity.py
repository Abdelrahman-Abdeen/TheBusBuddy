from dataclasses import dataclass

from src.domain.entities.base_entity import BaseEntity


@dataclass
class User(BaseEntity):
    first_name: str
    last_name: str
    email: str
    password: str
    phone_number: str
    id: int | None = None
    device_token: str | None = None
    notifications: list[int] | None = None
    