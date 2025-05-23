from dataclasses import dataclass

@dataclass(frozen=True)
class Location:
    latitude: float
    longitude: float