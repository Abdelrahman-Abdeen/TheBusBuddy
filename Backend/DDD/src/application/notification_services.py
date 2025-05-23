from datetime import datetime
from src.domain.entities.event_entity import Event
from src.infrastructure.repositories.notification_repo import NotificationRepo
from src.domain.enums.event_type import EventType
from sqlalchemy.ext.asyncio import AsyncConnection
from typing import Any
import httpx
from firebase_admin import messaging
from src.infrastructure.repositories.user_repo import UserRepo
from src.infrastructure.repositories.student_repo import StudentRepo
import os
from dotenv import load_dotenv

load_dotenv()

GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")


class NotificationServices:
    def __init__(self):
        self.repo = NotificationRepo()
        self.user_repo = UserRepo()
        self.student_repo = StudentRepo()
    
    async def get_address_from_coordinates(self, latitude, longitude):
        """Get human-readable address from coordinates using Google Maps API"""
        if not GOOGLE_MAPS_API_KEY:
            return f"Location ({latitude}, {longitude})"

        url = f"https://maps.googleapis.com/maps/api/geocode/json?latlng={latitude},{longitude}&key={GOOGLE_MAPS_API_KEY}"
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url)
                data = response.json()

                if data["status"] == "OK" and data["results"]:
                    components = data["results"][0]["address_components"]
                    sublocality = None
                    street = None

                    for comp in components:
                        if "sublocality" in comp["types"] or "sublocality_level_1" in comp["types"]:
                            sublocality = comp["long_name"]
                        if "route" in comp["types"]:
                            street = comp["long_name"]

                    if sublocality and street:
                        return f"{sublocality} - {street}"
                    elif sublocality:
                        return sublocality
                    elif street:
                        return street
                    else:
                        return data["results"][0]["formatted_address"]
                else:
                    return f"Location ({latitude}, {longitude})"
            except Exception as e:
                print(f"Error getting address: {e}")
                return f"Location ({latitude}, {longitude})"


    async def create_from_student_event(self, connection: AsyncConnection, event: Event):
        print("=================================22222222222")
        parent_ids = await self.repo.get_parents_by_student_id(event.student_id, connection)
        admin_ids = await self.repo.get_admins_by_bus_id(event.bus_id, connection)
        recipient_roles = [(pid, "parent") for pid in parent_ids] + [(aid, "admin") for aid in admin_ids]
        enabled_parent_ids = await self.repo.get_enabled_parent_ids_for_event_type(event.event_type.name, parent_ids, connection)
        print("enabled:", enabled_parent_ids);
        ids = [pid for pid in enabled_parent_ids] + [aid for aid in admin_ids]
        print("ids:", ids)
        # Get student name
        student = await self.student_repo.get_by_id(event.student_id, connection)
        student_name = f"{student.first_name} {student.last_name}" if student else f"Student {event.student_id}"
        
        # Get address from coordinates
        address = await self.get_address_from_coordinates(event.location.latitude, event.location.longitude)
        
        message = f"{student_name} {event.event_type.value} bus {event.bus_id} at {event.time.strftime('%H:%M')}, at {address}"
        new_title = f"{student.first_name} {event.event_type.value}s"
        await self.repo.create_notification_with_roles(
            connection=connection,
            title=new_title,
            message=message,
            event_id=event.id,
            recipient_roles=recipient_roles
        )
        print("now want to push the")
        print("=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ids: ", ids)
        tokens = await self.user_repo.get_device_tokens_by_user_ids(ids, connection)
        for token in tokens:
            await self.push_notification(token, new_title, message)

    async def create_from_bus_event(self, connection: AsyncConnection, event: Event):
        parent_ids = await self.repo.get_parents_by_bus_id(event.bus_id, connection)
        admin_ids = await self.repo.get_admins_by_bus_id(event.bus_id, connection)

        recipient_roles = [(pid, "parent") for pid in parent_ids] + [(aid, "admin") for aid in admin_ids]

        message = f"{event.event_type.value} on bus {event.bus_id} at {event.time.strftime('%H:%M')}"
        title = f"Bus {event.event_type.value}"

        await self.repo.create_notification_with_roles(
            connection=connection,
            title=title,
            message=message,
            event_id=event.id,
            recipient_roles=recipient_roles
        )

        # ✅ New Part: Push notification to device tokens
        ids = parent_ids + admin_ids
        tokens = await self.user_repo.get_device_tokens_by_user_ids(ids, connection)
        for token in tokens:
            await self.push_notification(token, title, message)


    async def create_from_admin(self, connection: AsyncConnection, title: str, message: str, event_id: int | None, recipient_ids: list[int]) -> int:
        recipient_roles = {rid: "parent" for rid in recipient_ids}
        notification_id = await self.repo.create_notification_with_roles_for_admin_notificaiton(
        connection=connection,
        title=title,
        message=message,
        event_id=event_id,
        recipient_roles=recipient_roles
    )

        # 2. Send push notifications
        tokens = await self.user_repo.get_device_tokens_by_user_ids(recipient_ids, connection)
        for token in tokens:
            await self.push_notification(token, title, message)

        # 2. Send push notifications
        tokens = await self.user_repo.get_device_tokens_by_user_ids(recipient_ids, connection)
        for token in tokens:
            await self.push_notification(token, title, message)

        return notification_id

    async def create_from_tracking(
    self,
    connection: AsyncConnection,
    title: str,
    message: str,
    parent_ids: list[int]
    ) -> int:
        # 1. Save notification for all parents
        recipient_roles = [(pid, "parent") for pid in parent_ids]
        notification_id = await self.repo.create_notification_with_roles(
            connection=connection,
            title=title,
            message=message,
            event_id=None,
            recipient_roles=recipient_roles
        )

        # 2. Push only to parents who have it enabled
        if title == "Student Missed Bus":
            enabled_parent_ids = parent_ids
        else:
            enabled_parent_ids = await self.repo.get_enabled_parent_ids_for_event_type(
                title, parent_ids, connection
            )
        tokens = await self.user_repo.get_device_tokens_by_user_ids(enabled_parent_ids, connection)
        for token in tokens:
            await self.push_notification(token, title, message)

        return notification_id


    async def get_all_with_recipients(self, connection: AsyncConnection):
        return await self.repo.get_all_with_recipients(connection)

    async def get_notifications_for_admin(self, connection: AsyncConnection, admin_id: int):
        return await self.repo.get_notifications_for_admin(connection, admin_id)

    async def get_notifications_for_parent(self, connection: AsyncConnection, parent_id: int):
        return await self.repo.get_notifications_for_parent(connection, parent_id)
    
    async def push_notification(self, token: str, title: str, message: str):
        print("=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= message: ", message, token)
        message = messaging.Message(
            token=token,
            notification=messaging.Notification(
                title=title,
                body=message
            ),
            android=messaging.AndroidConfig(
                priority="high"
            )
        )

        try:
            response = messaging.send(message)
            print(f"✅ Successfully sent message: {response}")
        except Exception as e:
            print(f"❌ Failed to send message: {e}")