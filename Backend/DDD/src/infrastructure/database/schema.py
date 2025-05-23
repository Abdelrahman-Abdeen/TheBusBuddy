from sqlalchemy import MetaData, Table, Column, Integer, String, JSON, Boolean, ForeignKey, DateTime, Float, Text, Enum
from src.domain.enums.event_type import EventType
from src.domain.enums.route_mode import RouteMode
from src.infrastructure.database.connection import engine , metadata
from src.domain.enums.route_preference import RoutePreference
import datetime


users = Table(
    "users", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("phone_number", String, unique=False, nullable=False),
    Column("first_name", String, nullable=False),
    Column("last_name", String, nullable=False),
    Column("email", String, unique=True),
    Column("password", String, nullable=False),
    Column("device_token", String, nullable=True),
)

admins = Table(
    "admins", metadata,
    Column("id", Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
)

parents = Table(
    "parents", metadata,
    Column("id", Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
)

students = Table(
    "students", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("first_name", String, nullable=False),
    Column("last_name", String, nullable=False),
    Column("bus_id", Integer, ForeignKey("buses.id", ondelete="CASCADE"), nullable=True),
    Column("phone_number", String, unique=True, nullable=True),
    Column("home_latitude", Float, nullable=True),  # Home location - Latitude
    Column("home_longitude", Float, nullable=True), # Home location - Longitude
    Column("current_status", String, default="out"), # Add this line
    Column("route_preference", Enum(RoutePreference), default=RoutePreference.BOTH),
)

parent_student = Table(
    "parent_student", metadata,
    Column("parent_id", Integer, ForeignKey("parents.id", ondelete="CASCADE"), primary_key=True),
    Column("student_id", Integer, ForeignKey("students.id", ondelete="CASCADE"), primary_key=True)
)

# New table for tracking notification status at the parent-student level
parent_student_notifications = Table(
    "parent_student_notifications", metadata,
    Column("parent_id", Integer, ForeignKey("parents.id", ondelete="CASCADE"), primary_key=True),
    Column("student_id", Integer, ForeignKey("students.id", ondelete="CASCADE"), primary_key=True),
    Column("is_notified_approach", Boolean, default=False),
    Column("is_notified_arrival", Boolean, default=False),
    Column("is_notified_missed_bus", Boolean, default=False),
    Column("was_bus_near", Boolean, default=False)
)

buses = Table(
    "buses", metadata,
    Column("id", Integer, primary_key=True),
    Column("latitude", Float, nullable=True),  # Bus location - Latitude
    Column("longitude", Float, nullable=True), # Bus location - Longitude
    Column("is_monitoring_enabled", Boolean, default=False),
    Column("admin_id", Integer, ForeignKey("admins.id", ondelete="CASCADE"), nullable=True),
    Column("driver_name", String, nullable=True),
    Column("driver_phone", String, nullable=True),
    Column("route_mode", Enum(RouteMode), default=RouteMode.MORNING),  # Using the RouteMode enum
)

notifications = Table(
    "notifications", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("title", String, nullable=False),
    Column("message", Text, nullable=False),
    Column("event_id", Integer, ForeignKey("events.id",ondelete="CASCADE"), nullable=True),
    Column("status", String, default="sent"),
    Column("created_at", DateTime, default=datetime.datetime.utcnow),
)

# ✅ NOTIFICATION-RECIPIENT JOIN TABLE (Many-to-Many)
notification_recipient = Table(
    "notification_recipient", metadata,
    Column("notification_id", Integer, ForeignKey("notifications.id",ondelete="CASCADE"), primary_key=True),
    Column("user_id", Integer, ForeignKey("users.id",ondelete="CASCADE"), primary_key=True),
    Column("role", String, nullable=False, primary_key=True),
    # I want to add the role (admin , parent)
)

events = Table(
    "events", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("event_type", Enum(EventType), nullable=False),  # "ENTER", "EXIT", "ARRIVAL"
    Column("bus_id", Integer, ForeignKey("buses.id", ondelete="CASCADE"), nullable=True),
    Column("student_id", Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=True),
    Column("latitude", Float, nullable=True),  # Event location - Latitude
    Column("longitude", Float, nullable=True), # Event location - Longitude
    Column("timestamp", DateTime, default=datetime.datetime.utcnow),
    Column("description", Text, nullable=True),
)

parent_notification_preferences = Table(
    "parent_notification_preferences", metadata,
    Column("parent_id", Integer, ForeignKey("parents.id", ondelete="CASCADE"), primary_key=True),
    Column("notification_type", String, primary_key=True),
    Column("is_enabled", Boolean, default=True)
)

images = Table(
    "images", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("image_url", String, nullable=False),
    Column("student_id", Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=True),
    Column("embedding", JSON, nullable=False)  # ✅ added this
)

# metadata.create_all(engine)
print("✅ Database schema created successfully!")
