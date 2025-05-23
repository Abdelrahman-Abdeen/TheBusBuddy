from sqlalchemy import select, update
from src.domain.entities.user_entity import User
from src.infrastructure.repositories.base_repo import BaseRepo
from src.infrastructure.database.schema import users ,admins , parents
from sqlalchemy.ext.asyncio import AsyncConnection
class UserRepo(BaseRepo[User]):
    def __init__(self):
        super().__init__(User, users)

        
    async def update(self, user_id: int, update_data: dict, connection: AsyncConnection) -> bool:
        stmt = (
            update(users)
            .where(users.c.id == user_id)
            .values(update_data)
        )
        result = await connection.execute(stmt)
        return result.rowcount > 0

    async def get_by_phone_number(self, phone_number: str, connection: AsyncConnection) -> User | None:
        print("ttt")
        stmt = users.select().where(users.c.phone_number == phone_number)
        result = await connection.execute(stmt)
        row = result.fetchone()
        if row:
            return User(
                id=row.id,
                first_name=row.first_name,
                last_name=row.last_name,
                email=row.email,
                password=row.password,
                phone_number=row.phone_number,
                device_token=row.device_token,
                notifications=[]
            )
        return None

    async def is_admin(self, connection: AsyncConnection, user_id: int) -> bool:
        stmt = select(admins).where(admins.c.id == user_id)
        result = await connection.execute(stmt)
        row = result.fetchone()
        return row is not None

    async def is_parent(self, connection: AsyncConnection, user_id: int) -> bool:
        stmt = select(parents).where(parents.c.id == user_id)
        result = await connection.execute(stmt)
        row = result.fetchone()
        return row is not None
    
    async def get_device_tokens_by_user_ids(self, user_ids: list[int], connection: AsyncConnection) -> list[str]:
        # First check if users exist
        stmt = select(users).where(users.c.id.in_(user_ids))
        result = await connection.execute(stmt)
        existing_users = result.fetchall()
        print("=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= Existing users: ", existing_users)
        
        # Then get device tokens
        stmt = select(users.c.device_token).where(
            users.c.id.in_(user_ids),
            users.c.device_token.isnot(None)
        )
        result = await connection.execute(stmt)
        rows = result.fetchall()
        print("=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= Users with device tokens: ", rows)
        return [row.device_token for row in rows if row.device_token]
    
    async def get_device_token(self, user_id: int, connection: AsyncConnection) -> str | None:
        stmt = select(users.c.device_token).where(users.c.id == user_id)
        result = await connection.execute(stmt)
        row = result.fetchone()
        return row.device_token if row else None
