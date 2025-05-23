from datetime import datetime
from sqlalchemy import insert, select, delete
from src.domain.value_objects.location import Location
from src.domain.enums.event_type import EventType
from src.domain.entities.event_entity import Event
from src.infrastructure.repositories.base_repo import BaseRepo
from src.infrastructure.database.schema import events
from sqlalchemy.ext.asyncio import AsyncConnection


class EventRepo(BaseRepo[Event]):
    def __init__(self):
        super().__init__(Event, events)

    async def create_event(self, connection: AsyncConnection, event_type: EventType, bus_id: int, student_id: int | None,
                     latitude: float, longitude: float) -> Event:

        now = datetime.now()

        stmt = (
            insert(events)
            .values(
                event_type=event_type.name,
                bus_id=bus_id,
                student_id=student_id,
                latitude=latitude,
                longitude=longitude,
                timestamp=now,
            )
            .returning(events.c.id)
        )

        result = await connection.execute(stmt)
        new_id = result.scalar_one()

        return Event(
            id=new_id,
            event_type=event_type,
            time=now,
            location=Location(latitude=latitude, longitude=longitude),
            bus_id=bus_id,
            student_id=student_id
        )
    
    def _map_row_to_entity(self, row) -> Event:
        row_dict = dict(row._mapping)

        location = Location(
            latitude=row_dict.pop("latitude"),
            longitude=row_dict.pop("longitude")
        )

        return Event(
            id=row_dict["id"],
            event_type=EventType(row_dict["event_type"]),
            time=row_dict["timestamp"],
            location=location,
            bus_id=row_dict["bus_id"],
            student_id=row_dict.get("student_id"),
        )
        
    async def get_recent_events_for_student(self, student_id: int, bus_id: int, connection: AsyncConnection, since_time=None) -> list[Event]:
        """
        Get recent events for a student on a specific bus.
        
        Args:
            student_id: The ID of the student
            bus_id: The ID of the bus
            connection: Database connection
            since_time: Optional timestamp to only consider events after this time
            
        Returns:
            List of events for the student on the bus
        """
        # Build the query
        query = select(events).where(
            events.c.student_id == student_id,
            events.c.bus_id == bus_id
        )
        
        # Add time filter if specified
        if since_time:
            query = query.where(events.c.timestamp >= since_time)
            
        # Order by timestamp descending to get most recent first
        query = query.order_by(events.c.timestamp.desc())
        
        # Execute the query
        result = await connection.execute(query)
        rows = result.fetchall()
        
        # Map rows to Event entities
        return [self._map_row_to_entity(row) for row in rows]
    
    async def delete_all(self, connection: AsyncConnection) -> None:
        """Delete all events."""
        await connection.execute(delete(events))