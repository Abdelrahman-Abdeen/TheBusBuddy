# src/core/face_model.py
from deepface import DeepFace

# Build it once when imported
deepface_model = DeepFace.build_model("Facenet")
print("✅ DeepFace model loaded successfully")
