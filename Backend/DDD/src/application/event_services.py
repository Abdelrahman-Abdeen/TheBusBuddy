from src.domain.value_objects.location import Location
from src.infrastructure.repositories.event_repo import EventRepo
from src.infrastructure.repositories.notification_repo import NotificationRepo
from src.infrastructure.repositories.bus_repo import BusRepo
from src.domain.enums.event_type import EventType
from src.infrastructure.database.unit_of_work import UnitOfWork
from src.domain.entities.event_entity import Event
from src.application.base_services import BaseServices
#from geopy.distance import geodesic
from src.infrastructure.repositories.student_repo import StudentRepo
from src.application.notification_services import NotificationServices
import os
from dotenv import load_dotenv
from fastapi import requests
from src.application.student_services import StudentServices
import httpx
from src.domain.enums.route_mode import RouteMode
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Get environment variables with defaults
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
SCHOOL_LATITUDE = os.getenv("SCHOOL_LATITUDE")
SCHOOL_LONGITUDE = os.getenv("SCHOOL_LONGITUDE")

# Validate and convert coordinates
try:
    if SCHOOL_LATITUDE is None or SCHOOL_LONGITUDE is None:
        raise ValueError("School coordinates not set in environment variables")
    SCHOOL_LATITUDE = float(SCHOOL_LATITUDE)
    SCHOOL_LONGITUDE = float(SCHOOL_LONGITUDE)
    logger.info(f"School coordinates loaded: {SCHOOL_LATITUDE}, {SCHOOL_LONGITUDE}")
except ValueError as e:
    logger.error(f"Error loading school coordinates: {str(e)}")
    # Set default coordinates (you should replace these with your actual school coordinates)
    SCHOOL_LATITUDE = 31.9539  # Default latitude
    SCHOOL_LONGITUDE = 35.9106  # Default longitude
    logger.warning(f"Using default coordinates: {SCHOOL_LATITUDE}, {SCHOOL_LONGITUDE}")

class EventServices(BaseServices[Event]):
    def __init__(self):
        event_repo = EventRepo()
        super().__init__(repo=event_repo, uow=UnitOfWork())
        self.repo: EventRepo = event_repo
        self.student_repo = StudentRepo()
        self.notification_repo = NotificationRepo()
        self.bus_repo = BusRepo()
        self.notification_service = NotificationServices()
        self.student_service = StudentServices()

    async def get_distance_in_meters(self, origin_lat, origin_lng, dest_lat, dest_lng) -> float:
        url = (
            f"https://maps.googleapis.com/maps/api/distancematrix/json"
            f"?origins={origin_lat},{origin_lng}"
            f"&destinations={dest_lat},{dest_lng}"
            f"&key={GOOGLE_MAPS_API_KEY}"
            f"&units=metric"
        )

        async with httpx.AsyncClient() as client:
            response = await client.get(url)
            data = response.json()

            if data["status"] == "OK":
                element = data["rows"][0]["elements"][0]
                if element["status"] == "OK":
                    return element["distance"]["value"]

            return float("inf")

    async def create_event_for_student(self, bus_id: int, student_id: int, data) -> dict:
        async with UnitOfWork() as uow:
            bus = await self.bus_repo.get_by_id(bus_id, uow.connection)
            if not bus:
                raise ValueError(f"Bus with ID {bus_id} not found.")
            
            student = await self.student_repo.get_by_id(student_id, uow.connection)
            if not student:
                event_type = self._parse_event_type(data.event_type)
                if event_type.value == "enter":
                    unauthorized_type = EventType.UNAUTHORIZED_ENTER
                elif event_type.value == "exit":
                    unauthorized_type = EventType.UNAUTHORIZED_EXIT
                else:
                    raise ValueError(f"Invalid event type for unauthorized person: {event_type.value}")

                event = await self.repo.create_event(
                    connection=uow.connection,
                    event_type=unauthorized_type,
                    bus_id=bus_id,
                    student_id=None,
                    latitude=bus.location.latitude,
                    longitude=bus.location.longitude,
                )

                await self.notification_service.create_from_bus_event(
                    connection=uow.connection,
                    event=event,
                )

                return {
                    "status": "success",
                    "event_id": event.id,
                    "message": f"Unauthorized {event_type.value} event created"
                }

            event_type = self._parse_event_type(data.event_type)
            actual_type = await self._determine_contextual_event_type(
                original_type=event_type,
                bus_lat=bus.location.latitude,
                bus_lng=bus.location.longitude,
                student_lat=student.home_location.latitude,
                student_lng=student.home_location.longitude,
            )

            event = await self.repo.create_event(
                connection=uow.connection,
                event_type=actual_type,
                bus_id=bus_id,
                student_id=student_id,
                latitude=bus.location.latitude,
                longitude=bus.location.longitude,
            )

            await self.notification_service.create_from_student_event(
                connection=uow.connection,
                event=event,
            )

            if event_type.value in ("enter", "unusual_enter", "enter_at_school"):
                new_status = "in_bus"
            elif event_type.value in ("exit", "unusual_exit", "exit_at_school"):
                new_status = "out"
            else:
                new_status = student.current_status

            await self.student_service.update(
                id=student_id,
                data={"current_status": new_status},
            )

            route_mode = await self.bus_repo.get_route_mode(bus_id, uow.connection)

            if event_type.value in ("enter_at_school") and route_mode == RouteMode.EVENING:
                if not bus.is_monitoring_enabled:
                    await self.bus_repo.update(uow.connection, bus_id, {"is_monitoring_enabled": True})

            elif event_type.value in ("exit", "unusual_exit", "exit_at_school") and route_mode == RouteMode.EVENING:
                students_in_bus = await self.student_service.get_students_currently_in_bus(bus_id, uow.connection)
                if not students_in_bus:
                    await self.bus_repo.update(uow.connection, bus_id, {"is_monitoring_enabled": False})

            return {"status": "success", "event_id": event.id}

    async def create_event_for_bus(self, bus_id: int, data) -> dict:
        async with UnitOfWork() as uow:
            bus = await self.bus_repo.get_by_id(bus_id, uow.connection)
            if not bus:
                raise ValueError(f"Bus with ID {bus_id} not found.")

            event_type = self._parse_event_type(data.event_type)

            event = await self.repo.create_event(
                connection=uow.connection,
                event_type=event_type,
                bus_id=bus_id,
                student_id=None,
                latitude=bus.location.latitude,
                longitude=bus.location.longitude,
            )

            await self.notification_service.create_from_bus_event(
                connection=uow.connection,
                event=event,
            )

            return {"status": "success", "event_id": event.id}

    async def _determine_contextual_event_type(
        self, original_type: EventType, bus_lat: float, bus_lng: float,
        student_lat: float, student_lng: float
    ) -> EventType:
        threshold = 80

        distance_to_home = await self.get_distance_in_meters(bus_lat, bus_lng, student_lat, student_lng)
        distance_to_school = await self.get_distance_in_meters(bus_lat, bus_lng, SCHOOL_LATITUDE, SCHOOL_LONGITUDE)

        is_enter = original_type.value == "enter"
        is_exit = original_type.value == "exit"
        
        if is_enter:
            if distance_to_home <= threshold and distance_to_home <= distance_to_school:
                return EventType.ENTER_AT_HOME
            elif distance_to_school <= threshold:
                return EventType.ENTER_AT_SCHOOL
            else:
                return EventType.UNUSUAL_ENTER

        elif is_exit:
            if distance_to_home <= threshold and distance_to_home <= distance_to_school:
                return EventType.EXIT_AT_HOME
            elif distance_to_school <= threshold:
                return EventType.EXIT_AT_SCHOOL
            else:
                return EventType.UNUSUAL_EXIT

        return original_type

    def _parse_event_type(self, value: str) -> EventType:
        try:
            return EventType(value)
        except ValueError:
            raise ValueError(f"Invalid event type: {value}")

    async def get_all_notifications(self):
        async with UnitOfWork() as uow:
            return await self.notification_repo.get_all_with_recipients(uow.connection)

    async def delete_all_events(self):
        async with UnitOfWork() as uow:
            return await self.repo.delete_all(uow.connection)

    async def delete_all_notifications(self):
        async with UnitOfWork() as uow:
            return await self.notification_repo.delete_all(uow.connection)

    async def delete_notification(self, notification_id: int):
        async with UnitOfWork() as uow:
            return await self.notification_repo.delete(notification_id, uow.connection)

    async def delete_all_notifications(self, user_role: str) -> dict:
        """Remove all notifications for a specific role by removing them from recipients."""
        async with UnitOfWork() as uow:
            try:
                if user_role == "superuser":
                    await self.notification_repo.delete_all(uow.connection)
                    return {
                        "status": "success",
                        "message": "All notifications deleted successfully"
                    }

                elif user_role in ["admin", "parent"]:
                    await self.notification_repo.remove_role_from_recipients(uow.connection, user_role)
                    return {
                        "status": "success",
                        "message": f"All notifications removed for {user_role}"
                    }

                raise ValueError(f"Invalid role for notification removal: {user_role}")

            except Exception as e:
                logger.error(f"Error removing notifications: {str(e)}")
                raise ValueError(f"Failed to remove notifications: {str(e)}")

    async def delete_notification(self, notification_id: int, user_role: str) -> dict:
        """Remove a specific role from a notification's recipients."""
        async with UnitOfWork() as uow:
            try:
                notification = await self.notification_repo.get_by_id(notification_id, uow.connection)
                if not notification:
                    raise ValueError(f"Notification with ID {notification_id} not found")

                if user_role == "superuser":
                    await self.notification_repo.delete(notification_id, uow.connection)
                    return {
                        "status": "success",
                        "message": "Notification deleted successfully"
                    }

                elif user_role in ["admin", "parent"]:
                    await self.notification_repo.remove_role_from_recipients(uow.connection, user_role, notification_id)
                    return {
                        "status": "success",
                        "message": f"Notification removed for {user_role}"
                    }

                raise ValueError(f"Invalid role for notification removal: {user_role}")

            except Exception as e:
                raise ValueError(f"Failed to remove notification: {str(e)}")