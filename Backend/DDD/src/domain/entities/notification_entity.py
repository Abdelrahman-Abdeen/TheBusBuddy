from dataclasses import dataclass
import datetime
from src.domain.entities.base_entity import BaseEntity

@dataclass
class Notification(BaseEntity):
    id: int
    title: str
    message: str
    event_id: int
    status: str
    created_at: datetime
    recipient: list[int] | None = None
