from dataclasses import dataclass

@dataclass
class StudentImage:
    id: int | None
    student_id: int
    image_url: str
    embedding: list[float]
