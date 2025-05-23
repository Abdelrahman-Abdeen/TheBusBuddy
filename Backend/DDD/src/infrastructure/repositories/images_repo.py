from sqlalchemy import select, insert, func
from src.domain.entities.image_entity import StudentImage
from src.infrastructure.repositories.base_repo import BaseRepo
from src.infrastructure.database.schema import images, students
from sqlalchemy.ext.asyncio import AsyncConnection

class ImageRepo(BaseRepo[StudentImage]):
    def __init__(self):
        super().__init__(StudentImage, images)

    async def get_images_by_student_ids(self, student_ids: list[int], connection: AsyncConnection) -> list[StudentImage]:
        stmt = select(images).where(images.c.student_id.in_(student_ids))
        result = await connection.execute(stmt)
        return [StudentImage(**row._mapping) for row in result.fetchall()]

    async def get_images_by_student_id(self, student_id: int, connection: AsyncConnection) -> list[StudentImage]:
        stmt = select(images).where(images.c.student_id == student_id)
        result = await connection.execute(stmt)
        return [StudentImage(**row._mapping) for row in result.fetchall()]

    async def get_images_by_bus_id(self, bus_id: int, connection: AsyncConnection) -> list[StudentImage]:
        stmt = (
            select(images)
            .join(students, students.c.id == images.c.student_id)
            .where(students.c.bus_id == bus_id)
        )
        result = await connection.execute(stmt)
        return [StudentImage(**row._mapping) for row in result.fetchall()]

    async def get_all_images(self, connection: AsyncConnection) -> list[StudentImage]:
        stmt = select(images)
        result = await connection.execute(stmt)
        return [StudentImage(**row._mapping) for row in result.fetchall()]

    async def save_image_and_embedding(self, student_id: int, image_url: str, embedding: list[float], connection: AsyncConnection):
        stmt = insert(images).values(
            student_id=student_id,
            image_url=image_url,
            embedding=embedding
        ).returning(images.c.id)
        result = await connection.execute(stmt)
        return result.scalar_one()
    
    async def count_student_images(self, student_id: int, connection: AsyncConnection) -> int:
        stmt = select(func.count()).select_from(images).where(images.c.student_id == student_id)
        result = await connection.execute(stmt)
        return result.scalar_one()
