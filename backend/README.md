# Pukaar Emergency Backend API

FastAPI backend service for Pukaar Emergency Response & Incident Management.

## Setup & Running Locally

### 1. Create & Activate Virtual Environment
```bash
python -m venv venv
# On Windows PowerShell:
.\venv\Scripts\Activate.ps1
# On Linux / macOS:
source venv/bin/activate
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Start Local Development Server
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 4. Test Health Endpoint
```bash
# In terminal or browser:
curl http://localhost:8000/health
```

### 5. Flutter Integration & Local Base URL
- **Local machine / Web / Desktop**: `http://localhost:8000`
- **Android Emulator**: `http://10.0.2.2:8000` (Loopback address for host machine)

To connect the Flutter app to this backend service, update `ServiceLocator`:
```dart
ServiceLocator.instance.init(useBackendApi: true);
```
Or set `AppConfig.useBackendApi = true` in `lib/core/config/app_config.dart`.
