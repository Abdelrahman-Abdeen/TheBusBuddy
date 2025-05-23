from datetime import datetime
from sqlalchemy import insert, select, outerjoin, join, delete
from sqlalchemy.ext.asyncio import AsyncConnection
from typing import List, Optional
from src.domain.entities.notification_entity import Notification
from src.infrastructure.database.schema import (
    notifications, notification_recipient,
    parent_student, students, events, buses, parent_notification_preferences
)
from src.infrastructure.repositories.base_repo import BaseRepo

class NotificationRepo(BaseRepo[Notification]):
    def __init__(self):
        super().__init__(Notification, notifications)

    async def create_notification_with_roles(self, connection: AsyncConnection, title: str | None, message: str, event_id: int | None, recipient_roles: dict[int, str]) -> int:
        stmt = (
            insert(notifications)
            .values(
                title=title,
                message=message,
                event_id=event_id,
                status="sent",
                created_at=datetime.now()
            )
            .returning(notifications.c.id)
        )
        result = await connection.execute(stmt)
        notification_id = result.scalar_one()

        unique = list(set(recipient_roles))

        # Prepare recipient inserts with roles
        recipient_data = [
            {"notification_id": notification_id, "user_id": uid, "role": role}
            for uid, role in unique
        ]
        await connection.execute(insert(notification_recipient).values(recipient_data))
        return notification_id
    
    async def create_notification_with_roles_for_admin_notificaiton(self, connection: AsyncConnection, title: str | None, message: str, event_id: int | None, recipient_roles: dict[int, str]) -> int:
        stmt = (
            insert(notifications)
            .values(
                title=title,
                message=message,
                event_id=event_id,
                status="sent",
                created_at=datetime.now()
            )
            .returning(notifications.c.id)
        )
        result = await connection.execute(stmt)
        notification_id = result.scalar_one()


        # Prepare recipient inserts with roles
        recipient_data = [
            {"notification_id": notification_id, "user_id": uid, "role": role}
            for uid, role in recipient_roles.items()
        ]
        await connection.execute(insert(notification_recipient).values(recipient_data))
        return notification_id

    async def get_parents_by_student_id(self, student_id: int, connection: AsyncConnection) -> List[int]:
        stmt = select(parent_student.c.parent_id).where(parent_student.c.student_id == student_id)
        result = await connection.execute(stmt)
        rows = result.fetchall()
        return [row.parent_id for row in rows]

    async def get_parents_by_bus_id(self, bus_id: int, connection: AsyncConnection) -> List[int]:
        stmt = (
            select(parent_student.c.parent_id)
            .select_from(
                parent_student.join(students, parent_student.c.student_id == students.c.id)
            )
            .where(students.c.bus_id == bus_id)
        )
        result = await connection.execute(stmt)
        rows = result.fetchall()
        return [row.parent_id for row in rows]

    async def get_admins_by_bus_id(self, bus_id: int, connection: AsyncConnection) -> List[int]:
        stmt = select(buses.c.admin_id).where(buses.c.id == bus_id)
        result = await connection.execute(stmt)
        rows = result.fetchall()
        return [row.admin_id for row in rows if row.admin_id is not None]

    async def get_all_with_recipients(self, connection: AsyncConnection) -> List[Notification]:
        j = outerjoin(
            notifications,
            notification_recipient,
            notifications.c.id == notification_recipient.c.notification_id
        )
        stmt = select(
            notifications,
            notification_recipient.c.user_id,
            notification_recipient.c.role
        ).select_from(j)

        result = await connection.execute(stmt)
        rows = result.fetchall()
        from collections import defaultdict
        grouped = defaultdict(lambda: {"recipients": []})

        for row in rows:
            notif = row._mapping
            nid = notif["id"]

            if "base" not in grouped[nid]:
                grouped[nid]["base"] = {
                    "id": nid,
                    "title": notif["title"],
                    "message": notif["message"],
                    "event_id": notif["event_id"],
                    "status": notif["status"],
                    "created_at": notif["created_at"],
                }

            user_id = notif.get("user_id")
            if user_id is not None:
                grouped[nid]["recipients"].append(user_id)

        return [
            Notification(**data["base"], recipient=data["recipients"])
            for data in grouped.values()
        ]

    async def get_notifications_for_admin(self, connection: AsyncConnection, admin_id: int) -> List[Notification]:
        stmt = (
            select(notifications)
            .select_from(
                notifications.join(notification_recipient)
            )
            .where(
                notification_recipient.c.user_id == admin_id,
                notification_recipient.c.role == "admin"
            )
        )
        result = await connection.execute(stmt)
        rows = result.fetchall()
        return [self._map_row_to_entity(row) for row in rows]

    async def get_notifications_for_parent(self, connection: AsyncConnection, parent_id: int) -> List[Notification]:
        stmt = (
            select(notifications)
            .select_from(
                notifications.join(notification_recipient)
            )
            .where(
                notification_recipient.c.user_id == parent_id,
                notification_recipient.c.role == "parent"
            )
        )
        result = await connection.execute(stmt)
        rows = result.fetchall()
        return [self._map_row_to_entity(row) for row in rows]
    
    async def get_enabled_parent_ids_for_event_type(self, event_type: str, parent_ids: list[int], connection: AsyncConnection) -> list[int]:
        # Map event type to notification type
        event_to_notification = {
            'ENTER_AT_HOME': 'enter',
            'EXIT_AT_HOME': 'exit',
            'ENTER_AT_SCHOOL': 'enter_at_school',
            'EXIT_AT_SCHOOL': 'exit_at_school',
            'UNUSUAL_EXIT': 'unusual_exit',
            'UNUSUAL_ENTER': 'unusual_enter',
            'APPROACH': 'approach',
            'ARRIVAL': 'arrival',
            'UNAUTHORIZED_ENTER': 'unauthorized_enter',
            'UNAUTHORIZED_EXIT': 'unauthorized_exit'
        }
        if event_type == "Bus Has Arrived":
            event_type = "ARRIVAL"
        elif event_type == "Bus Approaching":
            event_type = "APPROACH"
        notification_type = event_to_notification.get(event_type)
        if not notification_type:
            return []
            
        stmt = (
            select(parent_notification_preferences.c.parent_id)
            .where(
                parent_notification_preferences.c.parent_id.in_(parent_ids),
                parent_notification_preferences.c.notification_type == notification_type,
                parent_notification_preferences.c.is_enabled == True
            )
        )
        result = await connection.execute(stmt)
        rows = result.fetchall()
        return [row[0] for row in rows]
    async def remove_role_from_recipients(self, connection: AsyncConnection, role: str, notification_id: Optional[int] = None) -> None:

        """Remove a specific role from notification recipients.

        If notification_id is provided, only removes from that specific notification.

        Otherwise, removes from all notifications."""

        stmt = delete(notification_recipient).where(notification_recipient.c.role == role)

        

        if notification_id is not None:

            stmt = stmt.where(notification_recipient.c.notification_id == notification_id)

            

        await connection.execute(stmt)



    async def delete_all(self, connection: AsyncConnection) -> None:

        """Delete all notifications and their recipients."""

        await connection.execute(delete(notifications))

    
