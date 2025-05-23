from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from datetime import datetime, timezone
from typing import Optional

import os

security = HTTPBearer()
VALID_ROLES = {"parent", "admin", "superuser"}

def get_token_from_header(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    return credentials.credentials

def validate_token_with_roles(required_roles: Optional[list[str]] = None):
    def _validator(token: str = Depends(get_token_from_header)) -> dict:
        secret_key = os.getenv("JWT_SECRET_KEY")
        if not secret_key:
            raise HTTPException(status_code=500, detail="JWT secret key not set")

        try:
            payload = jwt.decode(token, secret_key, algorithms=["HS256"])
        except JWTError:
            raise HTTPException(status_code=401, detail="Invalid token")

        # Check expiration
        exp = payload.get("exp")
        if exp is None or datetime.fromtimestamp(exp, tz=timezone.utc) < datetime.now(timezone.utc):
            raise HTTPException(status_code=401, detail="Token expired")

        # Role check
        role = payload.get("role")
        if required_roles and role not in required_roles:
            raise HTTPException(
                status_code=403,
                detail=f"Access denied: requires one of roles {required_roles}"
            )

        return payload

    return _validator