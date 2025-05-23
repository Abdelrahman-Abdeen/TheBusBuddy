import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, storage

load_dotenv()
cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
bucket_name = os.getenv("FIREBASE_BUCKET_NAME")
cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred, {
    'storageBucket': bucket_name
})
print("Firebase initialized with storagesuccessfully!")
