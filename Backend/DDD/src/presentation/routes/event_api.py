from fastapi import APIRouter, Depends
from pydantic import BaseModel
from src.application.event_services import EventServices
from src.presentation.models.event_notification_models import EventCreateRequest
from src.presentation.middleware.auth_middleware import validate_token_with_roles
router = APIRouter(tags=["Event"])
event_services = EventServices()

@router.post("/event/{bus_id}/{student_id}")
async def create_student_event(bus_id: int, student_id: int, event: EventCreateRequest):
    return await event_services.create_event_for_student(bus_id, student_id, event)

@router.post("/event/{bus_id}")
async def create_bus_event(bus_id: int, event: EventCreateRequest, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await event_services.create_event_for_bus(bus_id, event)

@router.get("/event")
async def get_events(payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await event_services.get_all()

@router.get("/event/{event_id}")
async def get_event(event_id: int, payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))):
    return await event_services.get_by_id(event_id)

@router.get('/notifications')
async def get_notifications(payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await event_services.get_all_notifications()

@router.delete("/event/all")
async def delete_all_events(payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await event_services.delete_all_events()

@router.delete("/notifications/all")
async def delete_all_notifications(payload: dict = Depends(validate_token_with_roles(["admin", "parent", "superuser"]))):
    user_role = payload.get("role")
    return await event_services.delete_all_notifications(user_role)

@router.delete("/notifications/{notification_id}")
async def delete_notification(notification_id: int, payload: dict = Depends(validate_token_with_roles(["admin", "parent", "superuser"]))):
    user_role = payload.get("role")
    return await event_services.delete_notification(notification_id, user_role)
