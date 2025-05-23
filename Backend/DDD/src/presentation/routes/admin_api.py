from fastapi import APIRouter, Depends
from pydantic import BaseModel
from src.application.admin_services import AdminServices
from src.presentation.models.user_models import CreateAdminRequest, NotificationCreateRequest
from src.presentation.models.bus_models import AssignBusesRequest
from src.presentation.middleware.auth_middleware import validate_token_with_roles

router = APIRouter( tags=["Admin"])
admin_services = AdminServices()



@router.post("/admin")  # For creatign an admin (needed for the WEBSITE)
async def create_admin(data: CreateAdminRequest, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await admin_services.create(data.model_dump())

@router.get("/admins")  # Just for me
async def get_admins(payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await admin_services.get_all()

# @router.get("/{admin_id}/buses/")  # Not really needed since 1 admin in our case


@router.get("/{admin_id}/notifications")  # NOT DONE YET
async def get_notifications(admin_id: int, payload: dict = Depends(validate_token_with_roles(["admin", "superuser"]))):
    return await admin_services.get_notifications(admin_id)


@router.post("/{admin_id}/notifications/create") # For the mobile app                 NOT WORKIN
async def create_notification(admin_id: int, data: NotificationCreateRequest, payload: dict = Depends(validate_token_with_roles(["admin", "superuser"]))):
    print(data.model_dump())
    return await admin_services.create_notification(admin_id, data.model_dump())


@router.post("/{admin_id}/assign-buses")
async def assign_buses(admin_id: int, data: AssignBusesRequest, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await admin_services.assign_buses(admin_id, data.bus_ids)



