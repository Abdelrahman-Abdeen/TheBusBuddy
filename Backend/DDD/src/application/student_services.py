from src.application.base_services import BaseServices
from src.domain.entities.student_entity import Student
from src.infrastructure.repositories.student_repo import StudentRepo
from src.infrastructure.database.unit_of_work import UnitOfWork
from src.infrastructure.repositories.images_repo import ImageRepo
from firebase_admin import storage
from deepface import DeepFace
from datetime import datetime
from PIL import Image
from io import BytesIO
import numpy as np
from fastapi import UploadFile, File
from src.infrastructure.repositories.bus_repo import BusRepo

def get_tracking_service():
    from src.application.tracking_service import BusTrackingService
    return BusTrackingService()

class StudentServices(BaseServices[Student]):
    def __init__(self):
        student_repo = StudentRepo()
        super().__init__(repo=student_repo, uow=UnitOfWork())
        self.repo: StudentRepo = student_repo
        self.image_repo = ImageRepo()

    async def assign_students_to_bus(self, bus_id: int, student_ids: list[int]):
        async with UnitOfWork() as uow:
            for student_id in student_ids:
                await self.repo.update(uow.connection, student_id, {"bus_id": bus_id})
            return {"status": "success", "assigned": student_ids}
        
    async def assign_parents_to_student(self, student_id: int, parent_ids: list[int]):
        async with UnitOfWork() as uow:
            await self.repo.assign_parents(uow.connection, student_id, parent_ids)
            return {"status": "success", "assigned_parents": parent_ids}

    async def get_events_for_student(self, student_id: int):
        async with UnitOfWork() as uow:
            return await self.repo.get_events_for_student(uow.connection, student_id)
        
    async def get_students_currently_in_bus(self, bus_id: int, connection) -> list:
        return await self.repo.get_students_in_bus(bus_id=bus_id, connection=connection)

    async def get_eta_to_home(self, student_id: int) -> int:
        student = await self.get_by_id(student_id)
        if not student:
            print("⚠️ Student not found")
            return None

        bus_id = student.bus_id
        if not bus_id:
            print("⚠️ Student is not assigned to a bus")
            return None

        tracking_service = get_tracking_service()
        eta_map = await tracking_service.estimate_eta_for_students(bus_id)

        return eta_map.get(student_id)

    async def get_student_images(self, student_id: int) -> list[dict]:
        async with UnitOfWork() as uow:
            images = await self.image_repo.get_images_by_student_id(student_id, uow.connection)
            return [
                {
                    "id": img.id,
                    "image_url": img.image_url,
                    "student_id": img.student_id,
                    "embedding": img.embedding
                }
                for img in images
            ]

    async def save_image_and_embedding(self, student_id: int, image_url: str, embedding: list[float]):
        async with UnitOfWork() as uow:
            await self.image_repo.save_image_and_embedding(student_id, image_url, embedding, uow.connection)
            return {"status": "success", "image_url": image_url, "embedding": embedding}

    async def handle_photo_upload(self, student_id: int, file: UploadFile):
        student = await self.get_by_id(student_id)
        student_name = f"{student.first_name}_{student.last_name}".lower().replace(" ", "_")

        async with UnitOfWork() as uow:
            photo_count = await self.image_repo.count_student_images(student_id, uow.connection)
            photo_index = photo_count + 1

        file_bytes = await file.read()
        img = Image.open(BytesIO(file_bytes))
        img_array = np.array(img)

        try:
            embedding = DeepFace.represent(img_path=img_array, model_name="SFace", detector_backend="yolov8")[0]["embedding"]
        except Exception as e:
            return {"error": f"Face not detected: {str(e)}"}

        extension = file.filename.split(".")[-1]
        firebase_filename = f"students/{student_id}_{student_name}_{photo_index}.{extension}"

        bucket = storage.bucket()
        blob = bucket.blob(firebase_filename)
        blob.upload_from_string(file_bytes, content_type=file.content_type)
        blob.make_public()
        image_url = blob.public_url

        await self.save_image_and_embedding(student_id, image_url, embedding)

        return {
            "status": "success",
            "image_url": image_url,
            "student_id": student_id,
            "photo_index": photo_index
        }

    async def get_students_in_bus_embeddings(self, bus_id: int) -> list[dict]:
        async with UnitOfWork() as uow:
            bus_repo = BusRepo()
            student_ids = await bus_repo.get_registered_students(bus_id, uow.connection)

            result = []
            for student_id in student_ids:
                student = await self.repo.get_by_id(student_id, uow.connection)
                if not student:
                    continue
                    
                images = await self.image_repo.get_images_by_student_id(student_id, uow.connection)
                for image in images:
                    if image:
                        result.append({
                            "student_id": student_id,
                            "student_name": f"{student.first_name} {student.last_name}",
                            "embedding": image.embedding
                        })
            return result
