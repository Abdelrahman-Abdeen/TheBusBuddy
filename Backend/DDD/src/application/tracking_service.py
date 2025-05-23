from src.infrastructure.repositories.event_repo import EventRepo
from src.infrastructure.repositories.student_repo import StudentRepo
from src.infrastructure.repositories.bus_repo import BusRepo
from src.infrastructure.repositories.notification_repo import NotificationRepo
from src.infrastructure.database.unit_of_work import UnitOfWork
from src.infrastructure.repositories.parent_repo import ParentRepo
from src.application.notification_services import NotificationServices
from src.domain.enums.route_mode import RouteMode
from dotenv import load_dotenv
from src.application.bus_services import BusServices
import os
import httpx
import asyncio


class BusTrackingService:
    def __init__(self):
        self.uow = UnitOfWork()
        self.repo = EventRepo()
        self.student_repo = StudentRepo()
        self.notification_repo = NotificationRepo()
        self.bus_service = BusServices()
        self.parent_repo = ParentRepo()
        self.notification_service = NotificationServices()
        self.bus_repo = BusRepo()
        load_dotenv()
        self.api_key = os.getenv("GOOGLE_MAPS_API_KEY")

    async def monitor_bus_tracking(self, bus_id: int):
        while True:
            async with UnitOfWork() as uow:
                bus = await self.bus_repo.get_by_id(bus_id, uow.connection)
                if not bus or not bus.is_monitoring_enabled:
                    print(f"🛑 Monitoring stopped for Bus {bus_id}")
                    break
                await self.check_bus_proximity_and_notify(bus_id, uow.connection)
            await asyncio.sleep(15)

    async def check_bus_proximity_and_notify(self, bus_id: int, connection):
        bus = await self.bus_service.get_by_id(bus_id)
        if not bus or not bus.location:
            return

        route_mode = await self.bus_repo.get_route_mode(bus_id, connection)
        print(f"🚌 Bus {bus_id} is in {route_mode.value} mode")

        students_to_process = []
        students_in_bus_objects = await self.bus_service.get_students_in_bus(bus_id)
        students_in_bus_ids = {student['id'] for student in students_in_bus_objects}

        if route_mode == RouteMode.MORNING:
            all_students = await self.bus_repo.get_registered_students(bus_id, connection)
            students_to_process = [s for s in all_students if s not in students_in_bus_ids]
            print(f"Students to notify: {students_to_process}")
        else:
            students_to_process = list(students_in_bus_ids)
            print(f"Students to notify in evening: {students_to_process}")

        if not students_to_process:
            return

        student_details = await self._get_students_batch(students_to_process, connection)
        parent_notification_map = await self._get_parent_notification_settings_batch(students_to_process, connection)

        tasks = []
        for student_id in students_to_process:
            student = student_details.get(student_id)
            if not student or not student.home_location:
                continue
            task = self._process_student_proximity(
                bus, student, student_id, students_in_bus_ids,
                parent_notification_map, route_mode, connection
            )
            tasks.append(task)

        await asyncio.gather(*tasks)

    async def _get_students_batch(self, student_ids, connection):
        students = {}
        for student_id in student_ids:
            student = await self.student_repo.get_by_id(student_id, connection)
            if student:
                students[student_id] = student
        return students

    async def _get_parent_notification_settings_batch(self, student_ids, connection):
        result = {}
        for student_id in student_ids:
            parents = await self.notification_repo.get_parents_by_student_id(student_id, connection)
            parent_settings = {}
            for parent_id in parents:
                settings = {
                    'approach': await self.parent_repo.is_notified_approach_for_student(parent_id, student_id, connection),
                    'arrival': await self.parent_repo.is_notified_arrival_for_student(parent_id, student_id, connection),
                    'missed': await self.parent_repo.is_notified_missed_bus_for_student(parent_id, student_id, connection)
                }
                parent_settings[parent_id] = settings
            result[student_id] = {
                'parents': parents,
                'settings': parent_settings,
                'was_near': await self.parent_repo.was_bus_near_student(student_id, connection)
            }
        return result

    async def _process_student_proximity(self, bus, student, student_id, students_in_bus_ids,
                                         parent_notification_map, route_mode, connection):
        distance = await self._get_distance(
            bus.location.latitude, bus.location.longitude,
            student.home_location.latitude, student.home_location.longitude
        )
        if distance is None:
            return

        student_data = parent_notification_map.get(student_id, {})
        parents = student_data.get('parents', [])
        parent_settings = student_data.get('settings', {})
        was_near = student_data.get('was_near', False)

        within_arrival = distance <= 100
        within_approach = 100 < distance <= 1000
        is_far = distance > 1000

        notification_updates = []
        notifications_to_send = []

        if within_arrival:
            for parent_id in parents:
                parent_setting = parent_settings.get(parent_id, {})
                if not parent_setting.get('arrival'):
                    notifications_to_send.append({
                        'parent_id': parent_id,
                        'title': "Bus Has Arrived",
                        'message': f"The bus has arrived at {student.first_name}'s home"
                    })
                    notification_updates.append(('arrival', parent_id, student_id, True))
                if not parent_setting.get('approach'):
                    notification_updates.append(('approach', parent_id, student_id, True))
            notification_updates.append(('was_near', None, student_id, True))

        elif within_approach:
            for parent_id in parents:
                parent_setting = parent_settings.get(parent_id, {})
                if not parent_setting.get('approach'):
                    notifications_to_send.append({
                        'parent_id': parent_id,
                        'title': "Bus Approaching",
                        'message': f"The bus is near {student.first_name}'s home"
                    })
                    notification_updates.append(('approach', parent_id, student_id, True))
            notification_updates.append(('was_near', None, student_id, True))

        elif is_far and route_mode == RouteMode.MORNING:
            if was_near:
                has_activity = await self.check_student_has_boarded_or_exited(student_id, bus.id, connection)
                if not has_activity:
                    for parent_id in parents:
                        parent_setting = parent_settings.get(parent_id, {})
                        if not parent_setting.get('missed'):
                            notifications_to_send.append({
                                'parent_id': parent_id,
                                'title': "Student Missed Bus",
                                'message': f"{student.first_name} has missed the bus. The bus arrived at your home but no boarding was detected."
                            })
                            notification_updates.append(('missed', parent_id, student_id, True))
                notification_updates.append(('was_near', None, student_id, False))
                for parent_id in parents:
                    parent_setting = parent_settings.get(parent_id, {})
                    if parent_setting.get('approach'):
                        notification_updates.append(('approach', parent_id, student_id, False))
                    if parent_setting.get('arrival'):
                        notification_updates.append(('arrival', parent_id, student_id, False))

        await self._batch_update_notification_settings(notification_updates, connection)

        for notification in notifications_to_send:
            await self.notification_service.create_from_tracking(
                connection,
                notification['title'],
                notification['message'],
                [notification['parent_id']]
            )

    async def _batch_update_notification_settings(self, updates, connection):
        for update_type, parent_id, student_id, value in updates:
            if update_type == 'approach':
                await self.parent_repo.set_is_notified_approach_for_student(parent_id, student_id, value, connection)
            elif update_type == 'arrival':
                await self.parent_repo.set_is_notified_arrival_for_student(parent_id, student_id, value, connection)
            elif update_type == 'missed':
                await self.parent_repo.set_is_notified_missed_bus_for_student(parent_id, student_id, value, connection)
            elif update_type == 'was_near':
                await self.parent_repo.set_was_bus_near_student(student_id, value, connection)

    async def _get_distance(self, origin_lat, origin_lng, dest_lat, dest_lng):
        if not self.api_key:
            return None
        origin = f"{origin_lat},{origin_lng}"
        destination = f"{dest_lat},{dest_lng}"
        url = (
            f"https://maps.googleapis.com/maps/api/directions/json?"
            f"origin={origin}&destination={destination}"
            f"&departure_time=now&traffic_model=best_guess"
            f"&key={self.api_key}"
        )
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url)
                data = response.json()
                if data.get("status") != "OK":
                    return None
                routes = data.get("routes", [])
                if not routes:
                    return None
                leg = routes[0].get("legs", [])[0]
                return leg.get("distance", {}).get("value", 0)
        except Exception:
            return None

    async def evaluate_exit_event_location(self, connection, student_id: int, bus_location: tuple[float, float]) -> bool:
        student = await self.student_repo.get_by_id(student_id, connection)
        if not student or not student.home_location:
            return False
        distance_m = await self._get_distance(
            bus_location[0],
            bus_location[1],
            student.home_location.latitude,
            student.home_location.longitude
        )
        return distance_m is not None and distance_m > 100

    async def estimate_eta_for_students(self, bus_id: int) -> dict:
        if not self.api_key:
            return {}
        bus = await self.bus_service.get_by_id(bus_id)
        if not bus or not bus.location:
            raise ValueError("Bus or location not found")
        students = await self.bus_service.get_students_in_bus(bus_id)
        if not students:
            return {}
        waypoints = []
        student_lookup = {}
        for idx, student in enumerate(students):
            lat = student.get("home_latitude")
            lng = student.get("home_longitude")
            if lat is not None and lng is not None:
                loc = f"{lat},{lng}"
                waypoints.append(loc)
                student_lookup[idx] = student["id"]
        if not waypoints:
            return {}
        origin = f"{bus.location.latitude},{bus.location.longitude}"
        if len(waypoints) == 1:
            url = (
                f"https://maps.googleapis.com/maps/api/directions/json?"
                f"origin={origin}&destination={waypoints[0]}"
                f"&departure_time=now&traffic_model=best_guess"
                f"&key={self.api_key}"
            )
        else:
            waypoints_str = "|".join(waypoints)
            url = (
                f"https://maps.googleapis.com/maps/api/directions/json?"
                f"origin={origin}"
                f"&destination={origin}"
                f"&waypoints=optimize:true|{waypoints_str}"
                f"&departure_time=now&traffic_model=best_guess"
                f"&key={self.api_key}"
            )
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(url)
                data = response.json()
                routes = data.get("routes", [])
                if not routes:
                    return {}
                legs = routes[0].get("legs", [])
                waypoint_order = routes[0].get("waypoint_order")
                eta_map = {}
                if waypoint_order is None or len(waypoint_order) == 0:
                    if len(legs) == 1 and len(student_lookup) == 1:
                        leg = legs[0]
                        duration = leg.get("duration_in_traffic", {}).get("value") or leg.get("duration", {}).get("value", 0)
                        student_id = next(iter(student_lookup.values()))
                        eta_map[student_id] = duration // 60
                else:
                    total_time = 0
                    for i, idx in enumerate(waypoint_order):
                        if i < len(legs):
                            leg = legs[i]
                            duration = leg.get("duration_in_traffic", {}).get("value") or leg.get("duration", {}).get("value", 0)
                            total_time += duration
                            student_id = student_lookup.get(idx)
                            if student_id:
                                eta_map[student_id] = total_time // 60
                return eta_map
        except Exception:
            return {}

    async def check_student_has_enter_event(self, student_id: int, bus_id: int, connection) -> bool:
        events = await self.repo.get_recent_events_for_student(student_id, bus_id, connection)
        return any(event.event_type == "ENTER" for event in events)

    async def check_student_has_boarded_or_exited(self, student_id: int, bus_id: int, connection, since_time=None) -> bool:
        events = await self.repo.get_recent_events_for_student(
            student_id=student_id,
            bus_id=bus_id,
            connection=connection,
            since_time=since_time
        )
        for event in events:
            if event.event_type in ["ENTER", "EXIT"]:
                print(f"Found {event.event_type} event for student {student_id} on bus {bus_id}")
                return True
        return False

    async def notify_student_missed_bus(self, student, parent_id: int, connection):
        is_notified_missed = await self.parent_repo.is_notified_missed_bus_for_student(parent_id, student.id, connection)
        if not is_notified_missed:
            print(f"Sending missed bus notification to parent {parent_id} for student {student.id}")
            await self.notification_service.create_from_tracking(
                connection=connection,
                title="Student Missed Bus",
                message=f"{student.first_name} has missed the bus. The bus arrived at your location but no boarding activity was detected. Please contact the school for alternative arrangements.",
                parent_ids=[parent_id],
            )
            await self.parent_repo.set_is_notified_missed_bus_for_student(parent_id, student.id, True, connection)
            print(f"Set missed bus notification to TRUE for parent {parent_id} and student {student.id}")
        else:
            print(f"Parent {parent_id} already notified about student {student.id} missing the bus")
