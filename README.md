# 🚨 Pukaar — Next-Gen Emergency Response & Dispatch System

**Pukaar** is a unified, high-availability emergency platform designed to connect citizens in distress with rapid-response dispatchers and emergency personnel. Built for Smart India Hackathon (SIH) 2026, Pukaar streamlines triage across four core emergency pillars, captures precise GPS telemetry, visualizes live incident locations on OpenStreetMap, and synchronizes real-time status transitions between citizens and responder dashboards.

---

## 🌟 Key Features

### 🛡️ Citizen Emergency Experience
- **Immediate SOS Trigger**: One-tap emergency broadcast with automated GPS coordinate capture.
- **Pillar-Based Triage Flow**: Specialized subcategory intent selection across 4 core pillars:
  - 🚑 **Medical Emergency** (Trauma care, Cardiac arrest, Ambulance request)
  - ♀️ **Women's Safety** (Harassment, SOS alert, Rapid escort)
  - 🌪️ **Disaster Management** (Flood, Fire, Earthquake rescue)
  - 🏫 **Campus Emergency** (University security, Campus distress)
- **Live Incident Tracking**: Real-time tracking screen displaying incident lifecycle progression (`Created` ➔ `Searching` ➔ `Dispatched` ➔ `Accepted` ➔ `In Progress` ➔ `Resolved` / `Cancelled`).
- **Interactive OpenStreetMap**: Visual location map (`flutter_map`) displaying captured incident coordinates and active responder pin.
- **Incident Cancellation**: Citizen-initiated cancellation with reason confirmation.

### 🚓 Emergency Responder System
- **Responder Dashboard**: Real-time active incident feed for emergency response units (`/responder-dashboard`).
- **One-Tap Status Lifecycle Management**: Responders can accept dispatches, initiate active response, and mark incidents resolved.
- **Responder GPS Context**: Displays current responder device location alongside citizen emergency coordinates.

### ⚙️ Production-Ready Backend & Architecture
- **FastAPI REST Service**: Python 3.10+ backend with in-memory incident persistence store and CORS middleware (`/incidents`, `/incidents/active`, `/incidents/{id}/status`, `/incidents/{id}/assign-responder`, `/health`).
- **Clean Architecture & Dependency Injection**: Modular service locator (`ServiceLocator`) allowing seamless switching between `MockEmergencyService` (demo mode) and `ApiEmergencyService` (live backend API).

---

## 📂 Architecture & Project Structure

```
pukaar/
├── lib/
│   ├── core/
│   │   ├── config/             # AppConfig, environment & API endpoints
│   │   ├── constants/          # AppColors, AppDimensions, AppStrings
│   │   ├── models/             # EmergencyIncident, EmergencyCategory, EmergencyStatus
│   │   ├── repositories/       # EmergencyRepository (API & Mock implementations)
│   │   ├── routing/            # AppRouter & AppRoutes
│   │   ├── services/           # ServiceLocator, ApiService, LocationService, AuthService
│   │   └── widgets/            # EmergencyMap (flutter_map / OpenStreetMap integration)
│   ├── features/
│   │   ├── auth/               # Login & Registration screens
│   │   ├── emergency/          # Intent Triage & Citizen Emergency Tracking screens
│   │   ├── home/               # Home dashboard & SOS trigger
│   │   ├── onboarding/         # Splash & Onboarding screens
│   │   ├── profile/            # Citizen Profile, Medical ID & Emergency Contacts
│   │   └── responder/          # Responder Dashboard screen
│   └── shared/                 # Reusable UI cards, buttons & state widgets
├── backend/                    # Python FastAPI Backend Service
│   ├── app/                    # FastAPI routes, models & store
│   ├── tests/                  # Pytest backend test suite
│   └── requirements.txt        # Backend dependencies
└── test/                       # Comprehensive Flutter Unit & Widget Test Suite
```

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.13.2`
- **Dart SDK**: `>= 3.13.2`
- **Python**: `>= 3.10`
- **Android Studio / VS Code** with Android Emulator

---

### 1. Flutter Mobile App Setup

```bash
# Clone repository & navigate to project directory
cd pukaar

# Install Flutter dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run Flutter test suite (49 passing tests)
flutter test

# Launch mobile application on Android Emulator
flutter run -d emulator-5554
```

---

### 2. FastAPI Backend Server Setup (Optional for Live API Mode)

The Flutter app runs in **Mock Mode** by default. To connect Flutter to the local FastAPI backend server:

```bash
# Navigate to backend directory
cd backend

# Create & activate virtual environment (optional)
python -m venv venv
# On Windows:
.\venv\Scripts\activate
# On Linux/macOS:
source venv/bin/activate

# Install backend dependencies
pip install -r requirements.txt

# Run pytest backend test suite (11 passing tests)
python -m pytest tests

# Start local FastAPI server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

#### Enabling Backend API Mode in Flutter
In `lib/main.dart`, pass `useBackendApi: true` to `ServiceLocator`:
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ServiceLocator.instance.init(useBackendApi: true);
  runApp(const PukaarApp());
}
```
*(Android Emulator connects to host backend via `http://10.0.2.2:8000`)*

---

## 🧪 Testing Summary

- **Flutter Unit & Widget Tests**: `49 / 49 Passed` (`flutter test`)
- **FastAPI Pytest Backend Suite**: `11 / 11 Passed` (`python -m pytest backend/tests`)
- **Flutter Code Analysis**: `0 Issues / Clean` (`flutter analyze`)

---

## 📄 License

This project is licensed under the MIT License — see the LICENSE file for details.
