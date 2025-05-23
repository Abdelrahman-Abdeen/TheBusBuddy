from src.infrastructure.repositories.base_repo import BaseRepo
from src.infrastructure.database.schema import admins, notification_recipient , users
from src.domain.entities.admin_entity import Admin
from sqlalchemy import Connection, insert, join, select, update
from src.domain.enums.event_type import EventType
from src.domain.entities.student_entity import Student
from sqlalchemy.ext.asyncio import AsyncConnection

class AdminRepo(BaseRepo[Admin]):
    def __init__(self):
        super().__init__(Admin, admins)


    async def get_all(self, connection: AsyncConnection) -> list[Admin]:
        stmt = (
            select(
                users.c.id,
                users.c.first_name,
                users.c.last_name,
                users.c.email,
                users.c.password,
                users.c.phone_number,
                users.c.device_token,
            )
            .select_from(join(admins, users, admins.c.id == users.c.id))
        )

        result = await connection.execute(stmt)
        return [self._map_row_to_entity(row) for row in result]

    def _map_row_to_entity(self, row) -> Admin:
        row_dict = dict(row._mapping)
        return Admin(
            id=row_dict["id"],
            first_name=row_dict["first_name"],
            last_name=row_dict["last_name"],
            email=row_dict["email"],
            password=row_dict["password"],
            phone_number=row_dict["phone_number"],
            device_token=row_dict.get("device_token"),
            notifications=[],
            buses_managed=[]
        )