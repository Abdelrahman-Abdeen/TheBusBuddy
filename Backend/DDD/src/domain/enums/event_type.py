from enum import Enum


class EventType(Enum):
    ENTER_AT_HOME = "enter"
    EXIT_AT_HOME = "exit"
    ENTER_AT_SCHOOL = "enter_at_school"
    EXIT_AT_SCHOOL = "exit_at_school"
    UNUSUAL_EXIT = "unusual_exit"
    UNUSUAL_ENTER = "unusual_enter"
    APPROACH = "approach"
    ARRIVAL = "arrival"
    UNAUTHORIZED_ENTER = "unauthorized_enter"
    UNAUTHORIZED_EXIT = "unauthorized_exit"