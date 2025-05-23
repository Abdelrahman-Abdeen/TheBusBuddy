from fastapi import FastAPI
from src.presentation.routes.parent_api import router as parent_router
from src.presentation.routes.bus_api import router as bus_router
from src.presentation.routes.student_api import router as student_router
from src.presentation.routes.admin_api import router as admin_router
from src.presentation.routes.event_api import router as event_router
from src.presentation.routes.auth_api import router as auth_router
from src.presentation.routes.user_routes import router as user_router
# import firebase_setup  # This will initialize Firebase
import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, storage
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()
cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
bucket_name = os.getenv("FIREBASE_BUCKET_NAME")
cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred, {
    'storageBucket': bucket_name
})
print("Firebase initialized with storagesuccessfully!")

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(parent_router)
app.include_router(bus_router)
app.include_router(student_router)
app.include_router(admin_router)
app.include_router(event_router)
app.include_router(auth_router)
app.include_router(user_router)
