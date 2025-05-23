from src.domain.value_objects.location import Location
from src.infrastructure.repositories.base_repo import BaseRepo
from src.infrastructure.database.schema import parents, users, parent_notification_preferences , students , parent_student, parent_student_notifications
from src.domain.entities.parent_entity import Parent
from sqlalchemy import insert, select, update
from sqlalchemy.ext.asyncio import AsyncConnection
from src.infrastructure.database.connection import engine
from src.domain.enums.event_type import EventType
from src.domain.entities.student_entity import Student

class ParentRepo(BaseRepo[Parent]):
    def __init__(self):
        super().__init__(Parent, parents)

    async def get_all(self, connection: AsyncConnection) -> list[Parent]:
        stmt = (
            select(*[col for col in users.c] + [col for col in parents.c if col.name != "id"])
            .join(parents, users.c.id == parents.c.id)
        )

        result = await connection.execute(stmt)
        rows = result.fetchall()
        return [self.entity_type(**dict(row._mapping)) for row in rows]

    async def get_by_id(self, id: int | str, connection: AsyncConnection) -> Parent | None:
        stmt = (
            select(*[col for col in users.c] + [col for col in parents.c if col.name != "id"])
            .join(parents, users.c.id == parents.c.id)
            .where(users.c.id == id)
        )
        result = await connection.execute(stmt)
        row = result.fetchone()

        if row:
            row_dict = dict(row._mapping)
            return self.entity_type(**row_dict)
        return None
    
    async def add(self, connection: AsyncConnection, parent: Parent) -> Parent:
        # Step 1: Filter fields to match 'parents' table
        parent_data = vars(parent)
        allowed_keys = set(parents.c.keys())
        filtered_data = {k: v for k, v in parent_data.items() if k in allowed_keys}

        # Step 2: Insert into parents table
        stmt = insert(parents).values(filtered_data)
        await connection.execute(stmt)

        # Step 3: Insert default preferences into parent_notification_preferences
        notification_types = [
            'enter', 'exit', 'enter_at_school', 'exit_at_school',
            'unusual_exit', 'unusual_enter', 'approach', 'arrival',
            'unauthorized_enter', 'unauthorized_exit'
        ]
        
        for notification_type in notification_types:
            await connection.execute(
                insert(parent_notification_preferences).values(
                    parent_id=parent.id,
                    notification_type=notification_type,
                    is_enabled=True
                )
            )

        return parent

    async def get_full_parent_info(self, parent_id: int, connection: AsyncConnection) -> Parent | None:   # NO NEEEED
        stmt = (
            select(users, parents)
            .join(parents, users.c.id == parents.c.id)
            .where(parents.c.id == parent_id)
        )
        result = await connection.execute(stmt).fetchone()

        if result:
            row_dict = dict(result._mapping)
            return self.entity_type(**row_dict)
        return None

    async def get_student_ids_by_parent_id(self, parent_id: int, connection: AsyncConnection) -> list[int]:
        stmt = (
            select(students.c.id)
            .join(parent_student, students.c.id == parent_student.c.student_id)
            .where(parent_student.c.parent_id == parent_id)
        )

        result = await connection.execute(stmt)
        rows = result.fetchall()
        return [row.id for row in rows]

    async def get_preferences(self, parent_id: int, connection: AsyncConnection) -> dict:
        stmt = (
            select(
                parent_notification_preferences.c.notification_type,
                parent_notification_preferences.c.is_enabled
            )
            .where(parent_notification_preferences.c.parent_id == parent_id)
        )
        result = await connection.execute(stmt)
        rows = result.fetchall()
        preferences = {
            row.notification_type: row.is_enabled
            for row in rows
        }
        return preferences
            
    async def update_preferences(self, parent_id: int, prefs: dict, connection: AsyncConnection) -> bool:
        updated_rows = 0

        for notification_type, is_enabled in prefs.items():
            stmt = (
                update(parent_notification_preferences)
                .where(
                    parent_notification_preferences.c.parent_id == parent_id,
                    parent_notification_preferences.c.notification_type == notification_type
                )
                .values(is_enabled=is_enabled)
            )

            result = await connection.execute(stmt)
            updated_rows += result.rowcount

        return updated_rows > 0

    # async def is_notified_approach(self, parent_id: int, connection: AsyncConnection) -> bool:
    #     stmt = select(parents.c.is_notified_approach).where(parents.c.id == parent_id)
    #     result = await connection.execute(stmt)
    #     value = result.scalar_one_or_none()

    #     return value is True

    # async def set_is_notified_approach(self, parent_id: int, value: bool, connection: AsyncConnection):
    #     stmt = (
    #         update(parents)
    #         .where(parents.c.id == parent_id)
    #         .values(is_notified_approach=value)
    #     )
    #     await connection.execute(stmt)

    # async def is_notified_arrival(self, parent_id: int, connection: AsyncConnection) -> bool:
    #     stmt = select(parents.c.is_notified_arrival).where(parents.c.id == parent_id)
    #     result = await connection.execute(stmt)
    #     value = result.scalar_one_or_none()

    #     return value is True

    # async def set_is_notified_arrival(self, parent_id: int, value: bool, connection: AsyncConnection):
    #     stmt = (
    #         update(parents)
    #         .where(parents.c.id == parent_id)
    #         .values(is_notified_arrival=value)
    #     )
    #     await connection.execute(stmt)

    async def is_notified_approach_for_student(self, parent_id: int, student_id: int, connection: AsyncConnection) -> bool:
        stmt = select(parent_student_notifications.c.is_notified_approach).where(
            parent_student_notifications.c.parent_id == parent_id,
            parent_student_notifications.c.student_id == student_id
        )
        result = await connection.execute(stmt)
        value = result.scalar_one_or_none()

        return value is True

    async def set_is_notified_approach_for_student(self, parent_id: int, student_id: int, value: bool, connection: AsyncConnection):
        # Check if the record exists
        stmt = select(parent_student_notifications).where(
            parent_student_notifications.c.parent_id == parent_id,
            parent_student_notifications.c.student_id == student_id
        )
        result = await connection.execute(stmt)
        record = result.fetchone()
        
        if record:
            # Update existing record
            stmt = (
                update(parent_student_notifications)
                .where(
                    parent_student_notifications.c.parent_id == parent_id,
                    parent_student_notifications.c.student_id == student_id
                )
                .values(is_notified_approach=value)
            )
        else:
            # Insert new record
            stmt = insert(parent_student_notifications).values(
                parent_id=parent_id,
                student_id=student_id,
                is_notified_approach=value,
                is_notified_arrival=False
            )
        
        await connection.execute(stmt)

    async def is_notified_arrival_for_student(self, parent_id: int, student_id: int, connection: AsyncConnection) -> bool:
        stmt = select(parent_student_notifications.c.is_notified_arrival).where(
            parent_student_notifications.c.parent_id == parent_id,
            parent_student_notifications.c.student_id == student_id
        )
        result = await connection.execute(stmt)
        value = result.scalar_one_or_none()

        return value is True

    async def set_is_notified_arrival_for_student(self, parent_id: int, student_id: int, value: bool, connection: AsyncConnection):
        # Check if the record exists
        stmt = select(parent_student_notifications).where(
            parent_student_notifications.c.parent_id == parent_id,
            parent_student_notifications.c.student_id == student_id
        )
        result = await connection.execute(stmt)
        record = result.fetchone()
        
        if record:
            # Update existing record
            stmt = (
                update(parent_student_notifications)
                .where(
                    parent_student_notifications.c.parent_id == parent_id,
                    parent_student_notifications.c.student_id == student_id
                )
                .values(is_notified_arrival=value)
            )
        else:
            # Insert new record
            stmt = insert(parent_student_notifications).values(
                parent_id=parent_id,
                student_id=student_id,
                is_notified_approach=False,
                is_notified_arrival=value
            )
        
        await connection.execute(stmt)

    async def was_bus_near_student(self, student_id: int, connection: AsyncConnection) -> bool:
        """Check if the bus was previously near this student."""
        stmt = select(parent_student_notifications.c.was_bus_near).where(
            parent_student_notifications.c.student_id == student_id
        )
        result = await connection.execute(stmt)
        rows = result.fetchall()
        
        # Return True if any parent-student pair has was_bus_near set to True
        return any(row[0] for row in rows)

    async def set_was_bus_near_student(self, student_id: int, value: bool, connection: AsyncConnection):
        """Set whether the bus was near this student."""
        # Get all parent-student pairs for this student
        stmt = select(parent_student_notifications).where(
            parent_student_notifications.c.student_id == student_id
        )
        result = await connection.execute(stmt)
        records = result.fetchall()
        
        if records:
            # Update existing records
            stmt = (
                update(parent_student_notifications)
                .where(parent_student_notifications.c.student_id == student_id)
                .values(was_bus_near=value)
            )
            await connection.execute(stmt)
        else:
            # Get all parents for this student
            stmt = select(parent_student.c.parent_id).where(
                parent_student.c.student_id == student_id
            )
            result = await connection.execute(stmt)
            parent_ids = [row.parent_id for row in result.fetchall()]
            
            # Insert new records for each parent
            for parent_id in parent_ids:
                stmt = insert(parent_student_notifications).values(
                    parent_id=parent_id,
                    student_id=student_id,
                    was_bus_near=value,
                    is_notified_approach=False,
                    is_notified_arrival=False,
                    is_notified_missed_bus=False
                )
                await connection.execute(stmt)

    async def is_notified_missed_bus_for_student(self, parent_id: int, student_id: int, connection: AsyncConnection) -> bool:
        """Check if a parent has been notified that their student missed the bus."""
        stmt = select(parent_student_notifications.c.is_notified_missed_bus).where(
            parent_student_notifications.c.parent_id == parent_id,
            parent_student_notifications.c.student_id == student_id
        )
        result = await connection.execute(stmt)
        value = result.scalar_one_or_none()

        return value is True

    async def set_is_notified_missed_bus_for_student(self, parent_id: int, student_id: int, value: bool, connection: AsyncConnection):
        """Set whether a parent has been notified that their student missed the bus."""
        # Check if the record exists
        stmt = select(parent_student_notifications).where(
            parent_student_notifications.c.parent_id == parent_id,
            parent_student_notifications.c.student_id == student_id
        )
        result = await connection.execute(stmt)
        record = result.fetchone()
        
        if record:
            # Update existing record
            stmt = (
                update(parent_student_notifications)
                .where(
                    parent_student_notifications.c.parent_id == parent_id,
                    parent_student_notifications.c.student_id == student_id
                )
                .values(is_notified_missed_bus=value)
            )
        else:
            # Insert new record
            stmt = insert(parent_student_notifications).values(
                parent_id=parent_id,
                student_id=student_id,
                is_notified_missed_bus=value,
                is_notified_approach=False,
                is_notified_arrival=False,
                was_bus_near=False
            )
        
        await connection.execute(stmt)

    async def reset_all_notification_flags(self, connection: AsyncConnection):
        """Reset all notification flags for all parent-student pairs."""
        try:
            # Update all records in parent_student_notifications
            stmt = update(parent_student_notifications).values(
                was_bus_near=False,
                is_notified_approach=False,
                is_notified_arrival=False,
                is_notified_missed_bus=False
            )
            await connection.execute(stmt)
            return True
        except Exception as e:
            print(f"Error resetting notification flags: {e}")
            return False

    async def reset_notification_flags_for_bus(self, bus_id: int, connection) -> bool:
        """
        Reset all notification flags for students assigned to a specific bus.
        This is useful when changing route modes to ensure a clean state.
        """
        try:
            # Get all students assigned to this bus
            query = select(students.c.id).where(students.c.bus_id == bus_id)
            result = await connection.execute(query)
            student_ids = [row.id for row in result]
            
            if not student_ids:
                print(f"No students found for bus {bus_id}")
                return True
                
            # Get all parents for these students
            parent_student_pairs = []
            for student_id in student_ids:
                query = select(parent_student.c.parent_id).where(parent_student.c.student_id == student_id)
                result = await connection.execute(query)
                parent_ids = [row.parent_id for row in result]
                
                for parent_id in parent_ids:
                    parent_student_pairs.append((parent_id, student_id))
            
            if not parent_student_pairs:
                print(f"No parent-student pairs found for bus {bus_id}")
                return True
                
            # Reset all notification flags for these parent-student pairs
            for parent_id, student_id in parent_student_pairs:
                # Reset approach notification
                await self.set_is_notified_approach_for_student(parent_id, student_id, False, connection)
                
                # Reset arrival notification
                await self.set_is_notified_arrival_for_student(parent_id, student_id, False, connection)
                
                # Reset missed bus notification
                await self.set_is_notified_missed_bus_for_student(parent_id, student_id, False, connection)
                
                # Reset was bus near flag
                await self.set_was_bus_near_student(student_id, False, connection)
            
            print(f"Reset notification flags for {len(parent_student_pairs)} parent-student pairs for bus {bus_id}")
            return True
            
        except Exception as e:
            print(f"Error resetting notification flags for bus {bus_id}: {e}")
            return False

    async def delete_notification_preferences(self, parent_id: int, conn):
        """Delete notification preferences for a parent."""
        try:
            stmt = (
                parent_notification_preferences.delete()
                .where(parent_notification_preferences.c.parent_id == parent_id)
            )
            await conn.execute(stmt)
        except Exception as e:
            raise Exception(f"Database error while deleting notification preferences: {str(e)}")

    async def delete(self, id: int | str, conn):
        """Delete a parent from the database."""
        try:
            stmt = (
                parents.delete()
                .where(parents.c.id == id)
            )
            await conn.execute(stmt)
        except Exception as e:
            raise Exception(f"Database error while deleting parent: {str(e)}")
