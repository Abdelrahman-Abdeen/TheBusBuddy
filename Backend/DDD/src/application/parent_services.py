from src.infrastructure.repositories.notification_repo import NotificationRepo
from src.infrastructure.repositories.user_repo import UserRepo
from src.application.base_services import BaseServices
from src.domain.entities.parent_entity import Parent
from src.infrastructure.repositories.parent_repo import ParentRepo
from src.infrastructure.database.unit_of_work import UnitOfWork
from src.domain.entities.user_entity import User
from typing import Any

from passlib.context import CryptContext
from jose import jwt
from datetime import datetime, timedelta

SECRET_KEY = "your_secret_key"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class ParentServices(BaseServices[Parent]):
    def __init__(self) -> None:
        parent_repo = ParentRepo()
        super().__init__(repo=parent_repo, uow=UnitOfWork())
        self.repo: ParentRepo = parent_repo
        self.user_repo = UserRepo()
        self.notification_repo = NotificationRepo()

    async def create(self, data: dict[str, Any]):
        async with UnitOfWork() as uow:
            data["password"] = pwd_context.hash(data["password"])

            user_entity = User(
                first_name=data['first_name'],
                last_name=data['last_name'],
                email=data['email'],
                password=data['password'],
                phone_number=data['phone_number'],
            )
            user = await self.user_repo.add(uow.connection, user_entity)
            parent_data = {
                "id": user.id,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "email": user.email,
                "password": user.password,
                "phone_number": user.phone_number,
                "device_token": user.device_token,
                "notifications": None,
                "notification_preferences": None,
                "students": None,
                "is_notified_arrival": False,
                "is_notified_approach": False,
            }
            parent = await self.repo.add(uow.connection, Parent(**parent_data))
            return parent

    async def update(self, id: int | str, data: dict[str, Any]) -> Parent:
        async with UnitOfWork() as uow:
            user_fields = ['phone_number', 'first_name', 'last_name', 'email', 'device_token']
            user_data = {k: v for k, v in data.items() if k in user_fields}
            
            if user_data:
                if not await self.user_repo.update(id, user_data, uow.connection):
                    raise ValueError('Failed to update user entity')
            
            if 'is_notified_arrival' in data:
                await self.repo.set_is_notified_arrival(id, data['is_notified_arrival'], uow.connection)
            if 'is_notified_approach' in data:
                await self.repo.set_is_notified_approach(id, data['is_notified_approach'], uow.connection)
            
            return await self._get_entity(id, uow.connection)

    async def get_students(self, parent_id: int):
        async with UnitOfWork() as uow:
            return await self.repo.get_student_ids_by_parent_id(parent_id, uow.connection)

    async def get_notifications(self, parent_id: int):
        async with UnitOfWork() as uow:
            return await self.notification_repo.get_notifications_for_parent(uow.connection, parent_id)

    async def get_notification_preferences(self, parent_id: int):
        async with UnitOfWork() as uow:
            return await self.repo.get_preferences(parent_id, uow.connection)

    async def update_notification_preferences(self, parent_id: int, update_data: dict[str, Any]):
        async with UnitOfWork() as uow:
            return await self.repo.update_preferences(parent_id, update_data, uow.connection)

    async def login(self, phone_number: str, password: str) -> str:
        async with UnitOfWork() as uow:
            user = await self.user_repo.get_by_phone_number(phone_number, uow.connection)

            if not user or not pwd_context.verify(password, user.password):
                raise Exception("Invalid credentials")
            isParent = await self.user_repo.is_parent(uow.connection, user.id)
            if not isParent:
                raise Exception("User is not a parent")

            payload = {
                "sub": str(user.id),
                "phone_number": user.phone_number,
                "role": "parent",
                "exp": datetime.now() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
            }

            return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

    async def reset_all_notification_flags(self):
        async with UnitOfWork() as uow:
            await self.repo.reset_all_notification_flags(uow.connection)
            return {"message": "All notification flags have been reset successfully"}

    async def reset_notification_flags_for_bus(self, bus_id: int):
        async with UnitOfWork() as uow:
            await self.repo.reset_notification_flags_for_bus(bus_id, uow.connection)
            return {"message": f"Notification flags have been reset for parents of students assigned to bus {bus_id}"}

    async def delete_notification_preferences(self, parent_id: int):
        async with UnitOfWork() as uow:
            try:
                await self.repo.delete_notification_preferences(parent_id, uow.connection)
                return {"message": "Notification preferences deleted successfully"}
            except Exception as e:
                raise Exception(f"Failed to delete notification preferences: {str(e)}")

    async def delete(self, parent_id: int):
        async with UnitOfWork() as uow:
            try:
                await self.repo.delete_notification_preferences(parent_id, uow.connection)
                await self.repo.delete(parent_id, uow.connection)
                return {"message": "Parent deleted successfully"}
            except Exception as e:
                raise Exception(f"Failed to delete parent: {str(e)}")
