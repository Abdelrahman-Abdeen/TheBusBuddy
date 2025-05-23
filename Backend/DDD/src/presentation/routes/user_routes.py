from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncConnection
from src.application.user_services import UserServices
from src.presentation.models.user_models import DeviceTokenUpdateRequest
from src.presentation.middleware.auth_middleware import validate_token_with_roles
router = APIRouter(tags=["User"])
user_services = UserServices()

@router.patch("/users/{user_id}/update_token")
async def update_user_device_token(
    user_id: int,
    request: DeviceTokenUpdateRequest,
    payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))
):
        return await user_services.update_user_device_token(
            user_id=user_id,
            device_token=request.device_token,
        )
    
@router.get("/users/{user_id}/device_token")
async def get_user_device_token(
    user_id: int,
    payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))
):
    return await user_services.get_user_device_token(user_id)


@router.post("/user/{user_id}/assign-role/{role}")
async def assign_role_to_user(user_id: int, role: str, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await user_services.assign_role(user_id, role)