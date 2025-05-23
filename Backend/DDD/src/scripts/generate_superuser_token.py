from jose import jwt
from datetime import datetime, timedelta
import os

SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-dev-secret")  # fallback for local testing
ALGORITHM = "HS256"

def create_superuser_token():
    payload = {
        "sub": "0",  # any ID you want
        "role": "superuser",
        "exp": datetime.utcnow() + timedelta(days=365)  # valid for 1 year
    }

    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return token

if __name__ == "__main__":
    print("Your superuser token:")
    print(create_superuser_token())
