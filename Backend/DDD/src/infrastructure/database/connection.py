from sqlalchemy import MetaData
from sqlalchemy.ext.asyncio import create_async_engine

import os
# DATABASE_URL = "postgresql+asyncpg://postgres:test123@localhost:5432/busbuddy"

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://postgres:test123@34.18.81.223:5432/busbuddy")
# DATABASE_URL='postgresql+asyncpg://postgres:test123@/busbuddy?host=/cloudsql/green-wares-455611-r3:me-central1:busbuddy-db'
# Create SQLAlchemy engine
engine = create_async_engine(DATABASE_URL, echo=True)
metadata = MetaData()
