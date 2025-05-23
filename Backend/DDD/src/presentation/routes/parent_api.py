from typing import Optional
from fastapi import APIRouter, HTTPException, Depends
from src.application.parent_services import ParentServices
from pydantic import BaseModel
from src.presentation.models.user_models import CreateParentRequest, UpdateParentRequest
from src.presentation.models.event_notification_models import NotificationPrefereces
from src.presentation.middleware.auth_middleware import validate_token_with_roles


router = APIRouter(tags=["Parent"])
parent_services = ParentServices()


# @router.post("/login")  # Still for AUTH0

@router.get("/parents")   # DONE
async def get_parents(payload: dict = Depends(validate_token_with_roles(["admin", "superuser"]))):
    return await parent_services.get_all()


@router.get("/parent/{parent_id}")  # get parent info DONE
async def get_parent(
    parent_id: int,
    payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))
):
    # If parent, verify they can only access their own info
    if payload["role"] == "parent" and int(payload["sub"]) != parent_id:
        raise HTTPException(status_code=403, detail="Cannot access other parent's information")
    return await parent_services.get_by_id(parent_id)


@router.post("/parent")  # create-parent   DONE
async def create_parent(
    data: CreateParentRequest,
    payload: dict = Depends(validate_token_with_roles(["admin", "superuser"]))
):
    return await parent_services.create(vars(data))



@router.patch("/parent/{parent_id}/edit")  # update parent    DONE
async def update_parent(
    parent_id: int,
    update_data: UpdateParentRequest,
    payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))
):
    # Verify parent is updating their own profile
    if payload["role"] == "parent" and int(payload["sub"]) != parent_id:
        raise HTTPException(status_code=403, detail="Cannot update other parent's information")

    data = update_data.model_dump(exclude_unset=True)

    return await parent_services.update(parent_id, data)


@router.get("/parent/{parent_id}/students")  # list children
async def list_students(
    parent_id: int,
    payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))
):
    # If parent, verify they can only access their own students
    if payload["role"] == "parent" and int(payload["sub"]) != parent_id:
        raise HTTPException(status_code=403, detail="Cannot access other parent's students")
    return await parent_services.get_students(parent_id)


@router.get("/parent/{parent_id}/notifications")  # view parent notifications when role = parent
async def get_parent_notifications(
    parent_id: int,
    payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))
):
    # If parent, verify they can only access their own notifications
    if payload["role"] == "parent" and int(payload["sub"]) != parent_id:
        raise HTTPException(status_code=403, detail="Cannot access other parent's notifications")
    return await parent_services.get_notifications(parent_id)


@router.get("/parent/{parent_id}/notification-preferences")
async def get_notification_preferences(
    parent_id: int,
    payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))
):
    # If parent, verify they can only access their own preferences
    if payload["role"] == "parent" and int(payload["sub"]) != parent_id:
        raise HTTPException(status_code=403, detail="Cannot access other parent's preferences")
    return await parent_services.get_notification_preferences(parent_id)


@router.put("/parent/{parent_id}/notification-preferences")
async def update_notification_preferences(
    parent_id: int,
    update_data: NotificationPrefereces,
    payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))
):
    # If parent, verify they can only update their own preferences
    if payload["role"] == "parent" and int(payload["sub"]) != parent_id:
        raise HTTPException(status_code=403, detail="Cannot update other parent's preferences")
    return await parent_services.update_notification_preferences(parent_id, vars(update_data))


@router.delete("/parent/{parent_id}")   # Done
async def delete_parent(
    parent_id: int,
    payload: dict = Depends(validate_token_with_roles(["superuser"]))
):
    try:
        return await parent_services.delete(parent_id)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete parent: {str(e)}"
        )


@router.post("/reset-all-notification-flags")
async def reset_all_notification_flags(
    payload: dict = Depends(validate_token_with_roles(["admin", "superuser"]))
):
    """Reset all notification flags for all parent-student pairs."""
    return await parent_services.reset_all_notification_flags()


@router.post("/reset-notification-flags-for-bus/{bus_id}")
async def reset_notification_flags_for_bus(
    bus_id: int,
    payload: dict = Depends(validate_token_with_roles(["admin", "superuser"]))
):
    """Reset notification flags for parents of students assigned to a specific bus."""
    return await parent_services.reset_notification_flags_for_bus(bus_id)
