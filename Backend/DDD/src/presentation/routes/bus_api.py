from fastapi import APIRouter, HTTPException, Depends, WebSocket
from pydantic import BaseModel

from src.application.bus_services import BusServices
from src.application.student_services import StudentServices
import asyncio
from src.presentation.models.bus_models import LocationRequest, BusCreateRequest, BusUpdateRequest
from src.presentation.models.student_models import StudentIdsRequest
from src.application.tracking_service import BusTrackingService
from src.presentation.middleware.auth_middleware import validate_token_with_roles
from src.application.websocket_services import WebSocketService
router = APIRouter(tags= ["Bus"])

bus_services = BusServices()
student_services = StudentServices()
tracking_service = BusTrackingService()
websocket_service = WebSocketService()

@router.get("/buses")
async def get_all_buses(payload: dict = Depends(validate_token_with_roles(["admin", "superuser"]))):
    return await bus_services.get_all()

@router.post("/bus")
async def create_bus(data: BusCreateRequest, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await bus_services.create(data.model_dump())

@router.get("/bus/{bus_id}")
async def get_bus(bus_id: int, payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))):
    return await bus_services.get_by_id(bus_id)

@router.delete("/bus/{bus_id}")
async def delete_bus(bus_id: int, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await bus_services.delete(bus_id)

@router.patch('/bus/{bus_id}')
async def update_bus(bus_id: int, data: BusUpdateRequest, payload: dict = Depends(validate_token_with_roles(["admin", "superuser"]))):
    return await bus_services.update(bus_id, data.model_dump(exclude_unset=True))

@router.patch("/bus/{bus_id}/location")
async def update_bus_location(bus_id: int, location: LocationRequest, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await bus_services.update(bus_id, location.model_dump(exclude_unset=True))

@router.post("/bus/{bus_id}/assign-students")
async def assign_students_to_bus(bus_id: int, data: StudentIdsRequest, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await student_services.assign_students_to_bus(bus_id, data.student_ids)

@router.get("/bus/{bus_id}/events")
async def get_events_for_bus(bus_id: int, payload: dict = Depends(validate_token_with_roles(["admin", "superuser"]))):
    return await bus_services.get_events_for_bus(bus_id)

@router.get("/bus/{bus_id}/students")        # NOT WORKIIIIIIIIIIIING
async def get_students_for_bus(bus_id: int, payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))):
    return await bus_services.get_students_for_bus(bus_id)

@router.get("/bus/{bus_id}/currently-in-bus-students")
async def get_students_in_bus(bus_id: int, payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))):
    return await bus_services.get_students_in_bus(bus_id)



@router.get("/bus/{bus_id}/routes")
async def get_eta_for_bus(bus_id: int, payload: dict = Depends(validate_token_with_roles(["admin", "superuser"]))):
    return await tracking_service.estimate_eta_for_students(bus_id)

# src/presentation/bus_api.py
@router.post("/bus/{bus_id}/start-tracking")
async def start_tracking_for_bus(bus_id: int, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    asyncio.create_task(tracking_service.monitor_bus_tracking(bus_id))
    return {"status": "tracking started", "bus_id": bus_id}

@router.get("/bus/{bus_id}/location")
async def get_bus_location(bus_id: int, payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))):
    bus = await bus_services.get_by_id(bus_id)
    if not bus:
        raise HTTPException(status_code=404, detail="Bus not found")
    return {
        "latitude": bus.location.latitude,
        "longitude": bus.location.longitude,
    }

@router.get("/bus/{bus_id}/students-embeddings")
async def get_students_embeddings_in_bus(bus_id: int, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    """
    Get all students' embeddings in a specific bus.
    Returns a list of dictionaries containing student ID, name, and their image embeddings.
    """
    return await student_services.get_students_in_bus_embeddings(bus_id)

@router.websocket("/ws/bus/{bus_id}/location")
async def websocket_bus_location(websocket: WebSocket, bus_id: int):
    """
    WebSocket endpoint for real-time bus location updates.
    This endpoint delegates the WebSocket handling to the WebSocketService.
    """
    await websocket_service.handle_bus_location_updates(websocket, bus_id)

