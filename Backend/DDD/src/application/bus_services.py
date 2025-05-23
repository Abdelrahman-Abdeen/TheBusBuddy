from src.domain.value_objects.location import Location
from src.application.base_services import BaseServices
from src.domain.entities.bus_entity import Bus
from src.infrastructure.repositories.bus_repo import BusRepo
from src.infrastructure.database.unit_of_work import UnitOfWork
from src.application.student_services import StudentServices
from typing import Any
from datetime import date

class BusServices(BaseServices[Bus]):
    def __init__(self):
        bus_repo = BusRepo()
        super().__init__(repo=bus_repo, uow=UnitOfWork())
        self.repo: BusRepo = bus_repo
        self.student_service = StudentServices()

    async def get_by_id(self, bus_id: int) -> Bus:
        async with UnitOfWork() as uow:
            conn = uow.connection

            # 1. Load the Bus
            bus = await self.repo.get_by_id(bus_id, conn)
            if not bus:
                raise ValueError("Bus not found")

            # 2. Registered students
            bus.registered_students = await self.repo.get_registered_students(bus_id, conn)

            # 3. Currently in‐bus students — return only their IDs
            current = await self.student_service.get_students_currently_in_bus(bus_id, conn)
            bus.currently_in_bus_students = [s["id"] for s in current] if current else []

            # 4. Events
            evts = await self.repo.get_events_for_bus(bus_id, conn)
            today = date.today()
            today_events = [e for e in evts if e.time.date() == today]
            bus.events = [e.id for e in today_events]

            return bus
        
    async def get_all(self) -> list[Bus]:
        async with UnitOfWork() as uow:
            conn = uow.connection

            buses = await self.repo.get_all(conn)
            today = date.today()

            for bus in buses:
                bus.registered_students = await self.repo.get_registered_students(bus.id, conn)
                current = await self.student_service.get_students_currently_in_bus(bus.id, conn)
                bus.currently_in_bus_students = [s["id"] for s in current] if current else []
                evts = await self.repo.get_events_for_bus(bus.id, conn)
                today_events = [e for e in evts if e.time.date() == today]
                bus.events = [e.id for e in today_events]

            return buses

    async def get_events_for_bus(self, bus_id: int):
        async with UnitOfWork() as uow:
            return await self.repo.get_events_for_bus(bus_id, uow.connection)

    async def get_students_in_bus(self, bus_id: int):
        async with UnitOfWork() as uow:
            return await self.student_service.get_students_currently_in_bus(bus_id, uow.connection)
        
    async def get_students_for_bus(self, bus_id: int):
        async with UnitOfWork() as uow:
            return await self.repo.get_students_for_bus(bus_id, uow.connection)

    async def update(self, id: int | str, data: dict[str, Any]) -> Bus:
        async with UnitOfWork() as uow:
            if 'route_mode' in data:
                print(f"🔄 Updating route mode for bus {id} to {data['route_mode']}")
                if not await self.repo.update_route_mode(id, data['route_mode'], uow.connection):
                    raise ValueError('Failed to update bus route mode')
                data = {k: v for k, v in data.items() if k != 'route_mode'}
            
            if data:
                if not await self.repo.update(uow.connection, id, data):
                    raise ValueError('Failed to update bus')
            
            return await self._get_entity(id, uow.connection)
