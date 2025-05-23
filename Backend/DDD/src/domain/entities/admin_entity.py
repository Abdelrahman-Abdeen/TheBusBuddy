from dataclasses import dataclass, field

from src.domain.entities.user_entity import User


@dataclass
class Admin(User):
    buses_managed: list[int] = field(default_factory=list)