from fastapi import WebSocket, WebSocketDisconnect
import asyncio
from typing import Dict, Set
from src.application.bus_services import BusServices
from src.infrastructure.database.unit_of_work import UnitOfWork

class WebSocketService:
    def __init__(self):
        self.bus_services = BusServices()
        self.active_connections: Dict[int, Set[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, bus_id: int):
        await websocket.accept()
        if bus_id not in self.active_connections:
            self.active_connections[bus_id] = set()
        self.active_connections[bus_id].add(websocket)
        print(f"New WebSocket connection for bus {bus_id}")

    def disconnect(self, websocket: WebSocket, bus_id: int):
        if bus_id in self.active_connections:
            self.active_connections[bus_id].remove(websocket)
            if not self.active_connections[bus_id]:
                del self.active_connections[bus_id]
        print(f"WebSocket disconnected for bus {bus_id}")

    async def broadcast_location(self, bus_id: int, location_data: dict):
        if bus_id in self.active_connections:
            for connection in self.active_connections[bus_id]:
                try:
                    await connection.send_json(location_data)
                except Exception as e:
                    print(f"Error broadcasting to connection: {e}")
                    await self.disconnect(connection, bus_id)

    async def get_bus_location(self, bus_id: int) -> dict:
        """Get bus location with proper connection management"""
        try:
            async with UnitOfWork() as uow:
                bus = await self.bus_services.get_by_id(bus_id)
                if not bus:
                    return {"error": "Bus not found"}
                
                return {
                    "latitude": bus.location.latitude,
                    "longitude": bus.location.longitude,
                }
        except Exception as e:
            print(f"Error getting bus location: {e}")
            return {"error": str(e)}

    async def handle_bus_location_updates(self, websocket: WebSocket, bus_id: int):
        """
        Handle WebSocket connection for bus location updates.
        This method manages the WebSocket lifecycle and location updates.
        """
        try:
            await websocket.accept()
            print(f"New WebSocket connection for bus {bus_id}")
            
            while True:
                try:
                    # Get bus location
                    bus = await self.bus_services.get_by_id(bus_id)
                    if not bus:
                        await websocket.send_json({"error": "Bus not found"})
                        break
                    
                    # Send location data
                    location_data = {
                        "latitude": bus.location.latitude,
                        "longitude": bus.location.longitude,
                    }
                    await websocket.send_json(location_data)
                    
                    # Wait before next update
                    await asyncio.sleep(1)
                    
                except Exception as e:
                    print(f"Error in location update loop for bus {bus_id}: {str(e)}")
                    await websocket.send_json({"error": str(e)})
                    break
                    
        except WebSocketDisconnect:
            print(f"Client disconnected from bus {bus_id} location websocket")
            self.disconnect(websocket, bus_id)
        except Exception as e:
            print(f"Error in websocket handler for bus {bus_id}: {str(e)}")
            try:
                await websocket.close()
            except:
                pass
            finally:
                self.disconnect(websocket, bus_id)
