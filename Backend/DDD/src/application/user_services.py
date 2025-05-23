from typing import Literal
from sqlalchemy.engine import Connection
from src.infrastructure.repositories.user_repo import UserRepo
from src.infrastructure.repositories.notification_repo import NotificationRepo
from src.infrastructure.database.unit_of_work import UnitOfWork
from src.infrastructure.repositories.admin_repo import AdminRepo
from src.infrastructure.repositories.parent_repo import ParentRepo
from src.domain.entities.admin_entity import Admin
from src.domain.entities.parent_entity import Parent
from sqlalchemy.ext.asyncio import AsyncConnection

class UserServices:
    def __init__(self):
        self.user_repo = UserRepo()
        self.notification_repo = NotificationRepo()
        self.admin_repo = AdminRepo()
        self.parent_repo = ParentRepo()

    async def assign_role(self, user_id: int, role: Literal["admin", "parent"]):
        async with UnitOfWork() as uow:
            user = await self.user_repo.get_by_id(user_id, uow.connection)
            if not user:
                raise ValueError("User not found")

            if role == "admin":
                await self.admin_repo.add(uow.connection, Admin(
                    id=user.id,
                    first_name=user.first_name,
                    last_name=user.last_name,
                    email=user.email,
                    password=user.password,
                    phone_number=user.phone_number,
                    device_token=user.device_token,
                    notifications=[],
                    buses_managed=[]
                ))
                return {"message": f"User {user_id} is now an admin."}

            elif role == "parent":
                parent = Parent(
                    id=user.id,
                    first_name=user.first_name,
                    last_name=user.last_name,
                    email=user.email,
                    password=user.password,
                    phone_number=user.phone_number,
                    device_token=user.device_token,
                    notifications=[],
                    students=[],
                    notification_preferences=None,
                    is_notified_arrival=True,
                    is_notified_approach=True
                )
                await self.parent_repo.add(uow.connection, parent)
                return {"message": f"User {user_id} is now a parent."}

            else:
                raise ValueError("Invalid role")

    async def update_user_device_token(self, user_id: int, device_token: str) -> dict:
        """Update a user's device token."""
        async with UnitOfWork() as uow:
            success = await self.user_repo.update(
                user_id=user_id,
                update_data={"device_token": device_token},
                connection=uow.connection
            )
            
            if success:
                return {"message": "Device token updated successfully"}
            else:
                raise ValueError("User not found or update failed")

    async def get_user_device_token(self, user_id: int) -> dict:
        async with UnitOfWork() as uow:
            device_token = await self.user_repo.get_device_token(user_id, uow.connection)
            return {"device_token": device_token}
