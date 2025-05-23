import gps
import time
import requests

# Create a GPS session
session = gps.gps(mode=gps.WATCH_ENABLE)

url = "https://fastapi-app-53203255780.me-central1.run.app/bus/1/location"

while True:
    session.next()

    if session.fix.mode >= 2:  # 2 is 2D fix, 3 is 3D fix
        latitude = session.fix.latitude
        longitude = session.fix.longitude

        print(f"Latitude: {latitude}")
        print(f"Longitude: {longitude}")

        data = {
            "latitude": latitude,
            "longitude": longitude
        }

        try:
            response = requests.patch(url, json=data)
            print("Sent to server, status:", response.status_code)
        except Exception as e:
            print("Error sending to server:", e)

    else:
        print("Waiting for GPS fix...")

    time.sleep(1)