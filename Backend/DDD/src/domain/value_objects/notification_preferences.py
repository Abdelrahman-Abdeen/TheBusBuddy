from pydantic import BaseModel

class NotificationPreferences(BaseModel):
    enter: bool = True
    exit: bool = True
    enter_at_school: bool = True
    exit_at_school: bool = True
    unusual_exit: bool = True
    approach: bool = True
    arrival: bool = True
    unauthorized_enter: bool = True
    unauthorized_exit: bool = True