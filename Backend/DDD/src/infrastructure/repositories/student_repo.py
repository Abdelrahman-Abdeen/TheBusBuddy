from sqlalchemy import insert, select, update
from src.domain.value_objects.location import Location
from src.domain.entities.student_entity import Student
from src.infrastructure.repositories.base_repo import BaseRepo
from src.infrastructure.database.schema import students , parent_student, events
from src.domain.entities.event_entity import Event
from src.domain.enums.event_type import EventType
from src.domain.enums.route_preference import RoutePreference
from sqlalchemy.ext.asyncio import AsyncConnection

class StudentRepo(BaseRepo[Student]):
    def __init__(self):
        super().__init__(Student, students)

    def _map_row_to_entity(self, row) -> Student:
        row_dict = dict(row._mapping)

        # Extract and remove flat lat/long fields
        latitude = row_dict.pop("home_latitude", None)
        longitude = row_dict.pop("home_longitude", None)

        location = None
        if latitude is not None and longitude is not None:
            location = Location(latitude=latitude, longitude=longitude)
            
        # Handle route_preference
        route_preference = row_dict.pop("route_preference", None)
        if route_preference is not None:
            route_preference = RoutePreference(route_preference)

        # Construct the Student entity
        return Student(home_location=location, route_preference=route_preference, **row_dict)

    async def assign_parents(self, connection: AsyncConnection, student_id: int, parent_ids: list[int]) -> None:
        stmt = insert(parent_student).values([
            {"student_id": student_id, "parent_id": pid}
            for pid in parent_ids
        ])
        await connection.execute(stmt)
    
    async def get_events_for_student(self, connection: AsyncConnection, student_id: int) -> list[Event]:
        stmt = select(events).where(events.c.student_id == student_id)
        result = await connection.execute(stmt)
        rows = result.fetchall()

        events_list = []
        for row in rows:
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
    
    async def get_students_in_bus(self, bus_id: int, connection: AsyncConnection) -> list:
        query = students.select().where(
            students.c.bus_id == bus_id,
            students.c.current_status == "in_bus"
        )
        result = await connection.execute(query)
        rows = result.fetchall()
        return [dict(row._mapping) for row in rows]
    
    async def get_parents_by_student_id(self, student_id: int, connection: AsyncConnection) -> list[int]:
        """
        Get all parent IDs associated with a student.
        
        Args:
            student_id: The ID of the student
            connection: Database connection
            
        Returns:
            List of parent IDs
        """
        stmt = (
            select(parent_student.c.parent_id)
            .where(parent_student.c.student_id == student_id)
        )
        result = await connection.execute(stmt)
        rows = result.fetchall()
        return [row.parent_id for row in rows]
    

    