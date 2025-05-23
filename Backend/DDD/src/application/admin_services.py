from sqlalchemy import insert
from src.application.base_services import BaseServices
from src.domain.entities.admin_entity import Admin
from src.infrastructure.repositories.admin_repo import AdminRepo
from src.infrastructure.database.unit_of_work import UnitOfWork
from src.infrastructure.repositories.user_repo import UserRepo
from typing import Any
from src.domain.entities.user_entity import User
from datetime import datetime
from src.infrastructure.database.schema import notifications, notification_recipient
from src.infrastructure.repositories.notification_repo import NotificationRepo
from src.application.notification_services import NotificationServices
from src.infrastructure.repositories.bus_repo import BusRepo
from src.infrastructure.repositories.student_repo import StudentRepo
from passlib.context import CryptContext
from jose import jwt
from datetime import datetime, timedelta

SECRET_KEY = "your_secret_key"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
class AdminServices(BaseServices[Admin]):
    def __init__(self):
        admin_repo = AdminRepo()
        super().__init__(repo=admin_repo, uow=UnitOfWork())
        self.repo: AdminRepo = admin_repo
        self.user_repo = UserRepo()
        self.notification_repo = NotificationRepo()
        self.notification_services = NotificationServices()
        self.bus_repo = BusRepo()
        self.student_repo = StudentRepo()

    async def create(self, data: dict[str, Any]) -> Admin:
        async with UnitOfWork() as uow:
            try:
                data["password"] = pwd_context.hash(data["password"])

                user = User(**data)
                await self.user_repo.add(uow.connection, user)

                admin = Admin(
                    id=user.id,
                    first_name=user.first_name,
                    last_name=user.last_name,
                    email=user.email,
                    password=user.password,
                    phone_number=user.phone_number,
                    device_token=user.device_token,
                    notifications=user.notifications or [],
                    buses_managed=[],
                )
                await self.repo.add(uow.connection, admin)

                return admin
            except Exception as e:
                raise ValueError(str(e))

    async def create_notification(self, admin_id: int, data: dict[str, Any]):
        async with UnitOfWork() as uow:
            student_ids = data.get('recipient_ids', [])
            if not student_ids:
                raise ValueError("No student IDs provided")
            
            parent_ids = []
            for student_id in student_ids:
                student = await self.student_repo.get_by_id(student_id, uow.connection)
                if not student:
                    raise ValueError(f"Student with ID {student_id} does not exist")
                
                parents = await self.student_repo.get_parents_by_student_id(student_id, uow.connection)
                parent_ids.extend(parents)
            
            if not parent_ids:
                raise ValueError("No parents found for the selected students")
            
            notification_id = await self.notification_services.create_from_admin(
                connection=uow.connection,
                title=data.get('title'),
                message=data.get('message'),
                event_id=data.get('event_id'),
                recipient_ids=parent_ids,
            )
            return {"status": "success", "notification_id": notification_id}

    async def assign_buses(self, admin_id: int, bus_ids: list[int]):
        async with UnitOfWork() as uow:
            for bus_id in bus_ids:
                await self.bus_repo.update(uow.connection, bus_id, {"admin_id": admin_id})
            return {"status": "success", "assigned_buses": bus_ids}

    async def get_notifications(self, admin_id: int):
        async with UnitOfWork() as uow:
            return await self.notification_repo.get_notifications_for_admin(uow.connection, admin_id)

    async def login(self, phone_number: str, password: str) -> str:
        async with UnitOfWork() as uow:
            user = await self.user_repo.get_by_phone_number(phone_number, uow.connection)
            if not user or not pwd_context.verify(password, user.password):
                raise Exception("Invalid credentials")
            isAdmin = await self.user_repo.is_admin(uow.connection, user.id)
            if not isAdmin:
                raise Exception("User is not an admin")

            payload = {
                "sub": str(user.id),
                "phone_number": user.phone_number,
                "role": "admin",
                "exp": datetime.now() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
            }

            return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
