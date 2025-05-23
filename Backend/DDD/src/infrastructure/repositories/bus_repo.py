from sqlalchemy import Connection, insert, select, update, or_
from src.domain.value_objects.location import Location
from src.domain.entities.bus_entity import Bus
from src.infrastructure.repositories.base_repo import BaseRepo
from src.infrastructure.database.schema import buses, students, events
from src.domain.entities.event_entity import Event
from src.domain.enums.event_type import EventType
from src.domain.enums.route_mode import RouteMode
from src.domain.entities.student_entity import Student
from src.infrastructure.repositories.parent_repo import ParentRepo
from src.domain.enums.route_preference import RoutePreference
from sqlalchemy.ext.asyncio import AsyncConnection

class BusRepo(BaseRepo[Bus]):
    def __init__(self):
        super().__init__(Bus, buses)

    async def get_by_id(self, bus_id: int, connection: AsyncConnection) -> Bus | None:
        stmt = select(buses).where(buses.c.id == bus_id)
        result = await connection.execute(stmt)
        row = result.fetchone()
        if row:
            return self._map_row_to_entity(row)
        return None
    
    async def get_location(self, bus_id: int, connection: AsyncConnection) -> Location | None:
        stmt = select(buses.c.latitude, buses.c.longitude).where(buses.c.id == bus_id)
        result = await connection.execute(stmt)
        result = result.fetchone()
        if result and result.latitude is not None and result.longitude is not None:
            return Location(latitude=result.latitude, longitude=result.longitude)
        return None
    
    def _map_row_to_entity(self, row) -> Bus:
        row_dict = dict(row._mapping)
        location = Location(
            latitude=row_dict.pop("latitude", None),
            longitude=row_dict.pop("longitude", None)
        )
        bus = Bus(location=location, **row_dict)
        return bus
    
    async def get_registered_students(self, bus_id: int, connection: AsyncConnection) -> list[int]:
        stmt = select(students.c.id).where(students.c.bus_id == bus_id)
        result = await connection.execute(stmt)
        return [row.id for row in result]

    # def get_events_for_bus(self, bus_id: int, connection: Connection) -> list[int]:
    #     stmt = select(events.c.id).where(events.c.bus_id == bus_id)
    #     result = connection.execute(stmt).fetchall()
    #     return [row.id for row in result]
    async def get_events_for_bus(self, bus_id: int, connection: AsyncConnection) -> list[Event]:
        stmt = select(events).where(events.c.bus_id == bus_id)
        result = await connection.execute(stmt)
        result = result.fetchall()
        
        events_list = []
        for row in result:
            row_dict = dict(row._mapping)

            event = Event(
                id=row_dict["id"],
                event_type=EventType(row_dict["event_type"]),
                time=row_dict["timestamp"],
                location=Location(
                    latitude=row_dict["latitude"],
                    longitude=row_dict["longitude"]
                ),
                bus_id=row_dict["bus_id"],
                student_id=row_dict.get("student_id")
            )
            events_list.append(event)

        return events_list

    async def get_students_for_bus(self, bus_id: int, connection: AsyncConnection) -> list[Student]:
        route_mode = await self.get_route_mode(bus_id, connection)
        
        # Convert RouteMode to RoutePreference for comparison
        route_preference = RoutePreference(route_mode.value)
        
        stmt = select(students).where(
                students.c.bus_id == bus_id,
                or_(students.c.route_preference == RoutePreference.BOTH, 
                    students.c.route_preference == route_preference)
            )
        result = await connection.execute(stmt)
        result = result.fetchall()

        student_list = []
        for row in result:
            row_dict = dict(row._mapping)

            location = Location(
                latitude=row_dict.pop("home_latitude", None),
                longitude=row_dict.pop("home_longitude", None)
            )

            student = Student(
                id=row_dict["id"],
                first_name=row_dict["first_name"], 
                last_name=row_dict["last_name"],
                phone_number=row_dict["phone_number"],
                bus_id=row_dict["bus_id"],
                home_location=location,
                current_status=row_dict["current_status"],
                route_preference=RoutePreference(row_dict["route_preference"]),
                events=[],
                parents=[],
                images=[]
            )

            student_list.append(student)

        return student_list

    async def update_route_mode(self, bus_id: int, route_mode: RouteMode, connection: AsyncConnection) -> bool:
        """
        Update the route mode for a bus and reset all notification flags.
        This ensures a clean state when switching between morning and evening routes.
        """
        try:
            # Update the route mode
            stmt = (
                update(buses)
                .where(buses.c.id == bus_id)
                .values(route_mode=route_mode)
            )
            await connection.execute(stmt)
            
            # Reset all notification flags for this bus
            parent_repo = ParentRepo()
            await parent_repo.reset_notification_flags_for_bus(bus_id, connection)
            
            print(f"Updated route mode to {route_mode.value} for bus {bus_id} and reset notification flags")
            return True
            
        except Exception as e:
            print(f"Error updating route mode for bus {bus_id}: {e}")
            return False

    async def get_route_mode(self, bus_id: int, connection: AsyncConnection) -> RouteMode:
        """Get the current route mode of a bus."""
        try:
            query = select(buses.c.route_mode).where(buses.c.id == bus_id)
            result = await connection.execute(query)
            route_mode = result.scalar()
            return route_mode or RouteMode.MORNING  # Default to MORNING if not set
        except Exception as e:
            print(f"Error getting bus route mode: {e}")
            return RouteMode.MORNING  # Default to MORNING on error