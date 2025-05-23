
# ✅ auth_api.py (for both parent and admin login endpoints)
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from src.infrastructure.repositories.user_repo import UserRepo
from src.application.admin_services import AdminServices
from src.application.parent_services import ParentServices
from src.presentation.models.user_models import LoginRequest

router = APIRouter()
admin_services = AdminServices()
parent_services = ParentServices()

@router.post("/admin/login")
async def admin_login(data: LoginRequest):
    try:
        token = await admin_services.login(data.phone_number, data.password)
        return {"access_token": token, "token_type": "bearer"}
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.post("/parent/login")
async def parent_login(data: LoginRequest):
    try:
        token = await parent_services.login(data.phone_number, data.password)
        return {"access_token": token, "token_type": "bearer"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))
