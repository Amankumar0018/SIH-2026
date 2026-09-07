import pytest
from datetime import datetime, timezone
from fastapi.testclient import TestClient
from app.main import app
from app.store import store, user_store
from app.models import EmergencyIncidentModel

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_stores():
    store.clear()
    user_store.clear()
    yield
    store.clear()
    user_store.clear()


@pytest.fixture
def citizen_headers():
    res = client.post("/auth/login", json={"mobileNumber": "9876543210", "password": "password123"})
    token = res.json()["accessToken"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def citizen_b_headers():
    client.post("/auth/register", json={
        "mobileNumber": "9111111111",
        "password": "password123",
        "name": "Citizen B",
        "emergencyContactName": "Contact",
        "emergencyContactPhone": "9999999999",
    })
    res = client.post("/auth/login", json={"mobileNumber": "9111111111", "password": "password123"})
    token = res.json()["accessToken"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def responder_headers():
    res = client.post("/auth/login", json={"mobileNumber": "9000000000", "password": "responder123"})
    token = res.json()["accessToken"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def dual_headers():
    res = client.post("/auth/login", json={"mobileNumber": "9999999999", "password": "dual123"})
    token = res.json()["accessToken"]
    return {"Authorization": f"Bearer {token}"}


# ==============================================================================
# Health & Root Tests
# ==============================================================================

def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "pukaar-backend"


def test_root_endpoint():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "Pukaar" in data["message"]


# ==============================================================================
# Core Incident Lifecycle & Functionality Tests
# ==============================================================================

def test_create_incident(citizen_headers):
    payload = {
        "userId": "9876543210",
        "category": "medical",
        "intent": "Ambulance Request",
        "latitude": 28.6139,
        "longitude": 77.2090,
        "accuracy": 5.0,
        "priority": "critical",
    }
    response = client.post("/incidents", json=payload, headers=citizen_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "success"
    incident = data["incident"]
    assert incident["id"].startswith("INC_")
    assert incident["userId"] == "9876543210"
    assert incident["category"] == "medical"
    assert incident["intent"] == "Ambulance Request"
    assert incident["latitude"] == 28.6139
    assert incident["longitude"] == 77.2090
    assert incident["status"] == "created"


def test_get_incident_by_id(citizen_headers):
    payload = {
        "category": "womenSafety",
        "intent": "Harassment Alert",
    }
    create_res = client.post("/incidents", json=payload, headers=citizen_headers)
    assert create_res.status_code == 201
    created_id = create_res.json()["incident"]["id"]

    response = client.get(f"/incidents/{created_id}", headers=citizen_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["incident"]["id"] == created_id
    assert data["incident"]["intent"] == "Harassment Alert"


def test_get_incident_not_found(citizen_headers):
    response = client.get("/incidents/NON_EXISTENT_ID", headers=citizen_headers)
    assert response.status_code == 404
    data = response.json()
    assert "not found" in data["detail"].lower()


def test_get_active_incidents(citizen_headers, responder_headers):
    res1 = client.post("/incidents", json={"category": "disaster", "intent": "Fire"}, headers=citizen_headers)
    res1_id = res1.json()["incident"]["id"]

    res2 = client.post("/incidents", json={"category": "campus", "intent": "Security"}, headers=citizen_headers)
    res2_id = res2.json()["incident"]["id"]
    client.put(f"/incidents/{res2_id}/status", json={"status": "resolved"}, headers=responder_headers)

    response = client.get("/incidents/active", headers=responder_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    incidents = data["incidents"]
    assert len(incidents) == 1
    assert incidents[0]["id"] == res1_id


def test_get_all_incidents(citizen_headers, responder_headers):
    client.post("/incidents", json={"category": "medical", "intent": "Injury"}, headers=citizen_headers)
    client.post("/incidents", json={"category": "campus", "intent": "Medical"}, headers=citizen_headers)

    response = client.get("/incidents", headers=responder_headers)
    assert response.status_code == 200
    data = response.json()
    assert len(data["incidents"]) == 2


def test_update_incident_status(citizen_headers, responder_headers):
    create_res = client.post("/incidents", json={"category": "medical", "intent": "Cardiac"}, headers=citizen_headers)
    inc_id = create_res.json()["incident"]["id"]

    response = client.put(f"/incidents/{inc_id}/status", json={"status": "dispatched"}, headers=responder_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["incident"]["status"] == "dispatched"

    response_patch = client.patch(f"/incidents/{inc_id}/status", json={"status": "inProgress"}, headers=responder_headers)
    assert response_patch.status_code == 200
    assert response_patch.json()["incident"]["status"] == "inProgress"


def test_update_status_invalid_status(citizen_headers, responder_headers):
    create_res = client.post("/incidents", json={"category": "medical", "intent": "Cardiac"}, headers=citizen_headers)
    inc_id = create_res.json()["incident"]["id"]
    response = client.put(f"/incidents/{inc_id}/status", json={"status": "invalidStatusName"}, headers=responder_headers)
    assert response.status_code == 400


def test_cancel_incident(citizen_headers):
    create_res = client.post("/incidents", json={"category": "womenSafety", "intent": "Safety Alert"}, headers=citizen_headers)
    inc_id = create_res.json()["incident"]["id"]

    response = client.post(f"/incidents/{inc_id}/cancel", json={"reason": "Resolved by citizen"}, headers=citizen_headers)
    assert response.status_code == 200
    data = response.json()
    assert data["incident"]["status"] == "cancelled"
    assert "Resolved by citizen" in data["incident"]["notes"]


def test_assign_responder(citizen_headers, responder_headers):
    create_res = client.post("/incidents", json={"category": "medical", "intent": "Ambulance"}, headers=citizen_headers)
    inc_id = create_res.json()["incident"]["id"]

    payload = {
        "responderId": "R_101",
        "responderName": "City Trauma Care #1",
        "responderPhone": "102",
        "responderType": "Advanced Life Support",
        "estimatedArrivalMinutes": 4,
    }
    response = client.post(f"/incidents/{inc_id}/assign-responder", json=payload, headers=responder_headers)
    assert response.status_code == 200
    data = response.json()
    incident = data["incident"]
    assert incident["assignedResponderId"] == "R_101"
    assert incident["assignedResponderName"] == "City Trauma Care #1"
    assert incident["assignedResponderPhone"] == "102"
    assert incident["estimatedArrivalMinutes"] == 4


# ==============================================================================
# Security & Ownership Tests (Phase 1 Hardening)
# ==============================================================================

def test_citizen_can_view_own_incident(citizen_headers):
    create_res = client.post(
        "/incidents",
        json={"category": "medical", "intent": "Cardiac Arrest"},
        headers=citizen_headers,
    )
    inc_id = create_res.json()["incident"]["id"]

    res = client.get(f"/incidents/{inc_id}", headers=citizen_headers)
    assert res.status_code == 200
    assert res.json()["incident"]["id"] == inc_id


def test_citizen_cannot_view_another_citizen_incident(citizen_headers, citizen_b_headers):
    create_res = client.post(
        "/incidents",
        json={"category": "womenSafety", "intent": "Harassment"},
        headers=citizen_headers,
    )
    inc_id = create_res.json()["incident"]["id"]

    # Citizen B attempts to access Citizen A's incident
    res = client.get(f"/incidents/{inc_id}", headers=citizen_b_headers)
    assert res.status_code == 403
    assert "forbidden" in res.json()["detail"].lower()


def test_responder_can_view_any_incident(citizen_headers, responder_headers):
    create_res = client.post(
        "/incidents",
        json={"category": "disaster", "intent": "Flood Rescue"},
        headers=citizen_headers,
    )
    inc_id = create_res.json()["incident"]["id"]

    # Responder can access the incident
    res = client.get(f"/incidents/{inc_id}", headers=responder_headers)
    assert res.status_code == 200
    assert res.json()["incident"]["id"] == inc_id


def test_dual_user_can_view_any_incident(citizen_headers, dual_headers):
    create_res = client.post(
        "/incidents",
        json={"category": "campus", "intent": "Security"},
        headers=citizen_headers,
    )
    inc_id = create_res.json()["incident"]["id"]

    # Dual user acting with responder authority
    res = client.get(f"/incidents/{inc_id}", headers=dual_headers)
    assert res.status_code == 200
    assert res.json()["incident"]["id"] == inc_id


def test_citizen_can_cancel_own_incident(citizen_headers):
    create_res = client.post(
        "/incidents",
        json={"category": "medical", "intent": "Injury"},
        headers=citizen_headers,
    )
    inc_id = create_res.json()["incident"]["id"]

    res = client.post(
        f"/incidents/{inc_id}/cancel",
        json={"reason": "Self-resolved"},
        headers=citizen_headers,
    )
    assert res.status_code == 200
    assert res.json()["incident"]["status"] == "cancelled"


def test_citizen_cannot_cancel_another_citizen_incident(citizen_headers, citizen_b_headers):
    create_res = client.post(
        "/incidents",
        json={"category": "medical", "intent": "Trauma"},
        headers=citizen_headers,
    )
    inc_id = create_res.json()["incident"]["id"]

    # Citizen B attempts to cancel Citizen A's incident
    res = client.post(
        f"/incidents/{inc_id}/cancel",
        json={"reason": "Malicious cancellation attempt"},
        headers=citizen_b_headers,
    )
    assert res.status_code == 403
    assert "forbidden" in res.json()["detail"].lower()

    # Verify incident was NOT cancelled
    verify_res = client.get(f"/incidents/{inc_id}", headers=citizen_headers)
    assert verify_res.json()["incident"]["status"] == "created"


def test_responder_can_cancel_incident(citizen_headers, responder_headers):
    create_res = client.post(
        "/incidents",
        json={"category": "disaster", "intent": "Fire"},
        headers=citizen_headers,
    )
    inc_id = create_res.json()["incident"]["id"]

    res = client.post(
        f"/incidents/{inc_id}/cancel",
        json={"reason": "Dispatcher cancelled: False Alarm"},
        headers=responder_headers,
    )
    assert res.status_code == 200
    assert res.json()["incident"]["status"] == "cancelled"


# ==============================================================================
# Server-Controlled Fields & Integrity Tests
# ==============================================================================

def test_client_user_id_cannot_override_authenticated_user(citizen_headers):
    payload = {
        "userId": "9999999999",  # Spoofed user ID
        "category": "medical",
        "intent": "Ambulance",
    }
    res = client.post("/incidents", json=payload, headers=citizen_headers)
    assert res.status_code == 201
    assert res.json()["incident"]["userId"] == "9876543210"  # Bound to caller mobile


def test_client_incident_id_ignored_server_generates_unique_id(citizen_headers):
    payload = {
        "id": "CUSTOM_SPOOFED_ID_123",
        "category": "womenSafety",
        "intent": "SOS Alert",
    }
    res = client.post("/incidents", json=payload, headers=citizen_headers)
    assert res.status_code == 201
    created_id = res.json()["incident"]["id"]
    assert created_id != "CUSTOM_SPOOFED_ID_123"
    assert created_id.startswith("INC_")


def test_server_generates_utc_timestamp(citizen_headers):
    payload = {
        "timestamp": "2000-01-01T00:00:00Z",  # Spoofed past timestamp
        "category": "campus",
        "intent": "Medical Issue",
    }
    res = client.post("/incidents", json=payload, headers=citizen_headers)
    assert res.status_code == 201
    ts_str = res.json()["incident"]["timestamp"]
    assert ts_str != "2000-01-01T00:00:00Z"
    parsed = datetime.fromisoformat(ts_str)
    assert parsed.year >= 2026


def test_client_status_ignored_starts_as_created(citizen_headers):
    payload = {
        "status": "resolved",  # Client attempts to create pre-resolved incident
        "category": "disaster",
        "intent": "Earthquake",
    }
    res = client.post("/incidents", json=payload, headers=citizen_headers)
    assert res.status_code == 201
    assert res.json()["incident"]["status"] == "created"


def test_invalid_priority_rejected(citizen_headers):
    payload = {
        "category": "medical",
        "intent": "Ambulance",
        "priority": "super_critical_invalid",
    }
    res = client.post("/incidents", json=payload, headers=citizen_headers)
    assert res.status_code == 400
    assert "invalid priority" in res.json()["detail"].lower()


def test_invalid_category_rejected(citizen_headers):
    payload = {
        "category": "unknown_category",
        "intent": "General",
    }
    res = client.post("/incidents", json=payload, headers=citizen_headers)
    assert res.status_code == 400
    assert "invalid category" in res.json()["detail"].lower()


def test_duplicate_incident_id_in_store_prevented():
    inc1 = EmergencyIncidentModel(
        id="INC_STATIC_001",
        userId="user_1",
        category="medical",
        intent="Test",
    )
    store.save(inc1)

    with pytest.raises(ValueError, match="already exists"):
        store.save(inc1)
