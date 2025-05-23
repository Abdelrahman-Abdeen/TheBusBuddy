from fastapi import APIRouter
from src.application.student_services import StudentServices
from fastapi import UploadFile, File
import uuid
import os
from firebase_admin import storage
from deepface import DeepFace
from datetime import datetime
from PIL import Image
from io import BytesIO
import numpy as np
from src.presentation.models.student_models import StudentCreateRequest, StudentUpdateRequest, ParentIdsRequest
from src.presentation.middleware.auth_middleware import validate_token_with_roles
from fastapi import Depends

router = APIRouter(tags=["Student"])
student_services = StudentServices()

@router.get("/students")
async def get_all_students(payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await student_services.get_all()

@router.post("/student")
async def create_student(data: StudentCreateRequest, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await student_services.create(data.model_dump())

@router.get("/student/{student_id}")
async def get_student(student_id: int, payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))):
    return await student_services.get_by_id(student_id)

@router.delete("/student/{student_id}")
async def delete_student(student_id: int, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await student_services.delete(student_id)

@router.patch("/student/{student_id}")
async def update_student(student_id: int, data: StudentUpdateRequest, payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))):
    student_data = data.model_dump(exclude_unset=True)
    
    return await student_services.update(student_id, student_data)

@router.post("/student/{student_id}/assign-parents")
async def assign_parents(student_id: int, data: ParentIdsRequest, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await student_services.assign_parents_to_student(student_id, data.parent_ids)

@router.get("/student/{student_id}/events")
async def get_events_for_student(student_id: int, payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))):
    return await student_services.get_events_for_student(student_id)

@router.get("/student/{student_id}/eta")
async def get_eta_to_home(student_id: int, payload: dict = Depends(validate_token_with_roles(["parent", "admin", "superuser"]))):
    return await student_services.get_eta_to_home(student_id)

@router.get("/student/{student_id}/images")
async def get_student_images(student_id: int, payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    """
    Get all images and their embeddings associated with a student.
    """
    return await student_services.get_student_images(student_id)

@router.post("/upload-photo")
async def upload_photo(student_id: int, file: UploadFile = File(...), payload: dict = Depends(validate_token_with_roles(["superuser"]))):
    return await student_services.handle_photo_upload(student_id, file)