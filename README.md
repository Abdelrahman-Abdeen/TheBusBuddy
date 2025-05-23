# 📚 BusBuddy

**BusBuddy** is a smart school bus tracking and student monitoring system designed to enhance student safety and provide real-time visibility for both parents and school administrators. The system leverages GPS tracking, face recognition, and cloud-based communication to log student events and automate transportation monitoring with high accuracy.

---

## 🧾 Description

BusBuddy provides a complete end-to-end solution for managing school transportation. The system tracks buses in real time, logs student events using facial recognition and GPS proximity, and pushes instant notifications to guardians and school staff.

Every student interaction with the bus is logged as an **event**, allowing guardians and administrators to view detailed records and receive immediate alerts if something unusual occurs.

---

## 🚀 Features

- 🚌 **Real-time Bus Tracking** using Google Maps
- 👨‍👩‍👧 **Parent App** to:
  - View current bus location
  - Track their child’s activity
  - Receive real-time alerts
- 🧑‍🏫 **Admin Dashboard** to manage:
  - Student and bus data
  - Event history and logs
- 🧠 **Object Tracking & Face Recognition** with DeepFace for accurate identity verification
- 📝 **Student Event Logging**, including:
  - `STUDENT_ENTERED_BUS_AT_HOME`
  - `STUDENT_EXITED_BUS_AT_HOME`
  - `STUDENT_ENTERED_BUS_AT_SCHOOL`
  - `STUDENT_EXITED_BUS_AT_SCHOOL`
  - `STUDENT_UNUSUAL_ENTER`
  - `STUDENT_UNUSUAL_EXIT`

- 🔔 **Push Notifications** through Firebase Cloud Messaging (FCM) for:
    - `STUDENT ENTER/EXIT EVENTS`
    - `BUS APPROACHING / ARRIVED`
    - `UNAUTHORIZED_ENTER / EXIT`
- ☁️ **Cloud-based Media & Data Storage** with Firebase and PostgreSQL
- 🛠️ Built with **Domain-Driven Design** and a modular, scalable architecture

---

## 🧑‍💻 Tech Stack

| Layer         | Technology                                   |
|---------------|----------------------------------------------|
| Mobile App    | Flutter                                      |
| Backend       | FastAPI (Python), PostgreSQL                 |
| AI            | SFace (Face Recognition), YOLOv11 (CV)       |
| Infra         | Docker, Firebase Storage, Google Cloud       |
| Architecture  | Domain-Driven Design, WebSockets, REST APIs  |

---

## 🧠 AI Model

The AI component in **BusBuddy** is responsible for detecting and identifying students in real time as they enter or exit the bus.

- 🎯 **YOLOv11**: Used for both **object detection** (e.g., people near the bus) and **face detection**
- 📍 **ByteTrack**: Handles **object tracking** across video frames for consistency and event timing
- 🧠 **SFace**: Used for **face recognition** to verify student identity

These models work together to automatically trigger student-related events and update the system without any manual input.

---
## 🛠️ Setup Instructions

### 📦 Prerequisites

- Python 3.10
- Flutter SDK
- PostgreSQL
- Firebase account & credentials
- Git

---

### 🚀 Backend Setup (FastAPI + PostgreSQL)

```bash
# Clone the repo
git clone https://github.com/Abdelrahman-Abdeen/TheBusBuddy.git
cd TheBusBuddy/Backend/DDD

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Apply migrations
alembic upgrade head

# Run server
uvicorn main:app --reload
```

---
### 🚀 Frontend Setup (Flutter)

```bash
cd ../../Frontend/busbuddyapp

# Install flutter dependecies
flutter pub get

# Set up Firebase configuration

# Add your google-services.json file to android/app/
# Add your GoogleService-Info.plist file to ios/Runner/

# Run the flutter app 
flutter run


