from dataclasses import dataclass, field

from src.domain.entities.user_entity import User
from src.domain.value_objects.notification_preferences import NotificationPreferences

@dataclass
class Parent(User):
    notification_preferences: NotificationPreferences = field(default_factory=NotificationPreferences)
    students: list[int] | None = None
    is_notified_approach: bool = False
    is_notified_arrival: bool = False
    