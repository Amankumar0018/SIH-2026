import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.store import store

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_store():
    store.clear()
    yield
    store.clear()


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


def test_create_incident():
    payload = {
        "userId": "9876543210",
        "category": "medical",
        "intent": "Ambulance Request",
        "latitude": 28.6139,
        "longitude": 77.2090,
        "accuracy": 5.0,
        "priority": "critical",
    }
    response = client.post("/incidents", json=payload)
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


def test_get_incident_by_id():
    # Create incident first
    payload = {
        "id": "INC_TEST_001",
        "userId": "user_123",
        "category": "womenSafety",
        "intent": "Harassment Alert",
    }
    create_res = client.post("/incidents", json=payload)
    assert create_res.status_code == 201

    # Retrieve incident
    response = client.get("/incidents/INC_TEST_001")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["incident"]["id"] == "INC_TEST_001"
    assert data["incident"]["intent"] == "Harassment Alert"


def test_get_incident_not_found():
    response = client.get("/incidents/NON_EXISTENT_ID")
    assert response.status_code == 404
    data = response.json()
    assert "not found" in data["detail"].lower()


def test_get_active_incidents():
    # Create active incident
    client.post("/incidents", json={"id": "INC_ACT_1", "category": "disaster", "intent": "Fire"})
    # Create resolved incident
    client.post("/incidents", json={"id": "INC_RES_1", "category": "campus", "intent": "Security", "status": "resolved"})

    response = client.get("/incidents/active")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    incidents = data["incidents"]
    assert len(incidents) == 1
    assert incidents[0]["id"] == "INC_ACT_1"


def test_get_all_incidents():
    client.post("/incidents", json={"id": "INC_1", "category": "medical", "intent": "Injury"})
    client.post("/incidents", json={"id": "INC_2", "category": "campus", "intent": "Medical"})

    response = client.get("/incidents")
    assert response.status_code == 200
    data = response.json()
    assert len(data["incidents"]) == 2


def test_update_incident_status():
    client.post("/incidents", json={"id": "INC_STATUS_1", "category": "medical", "intent": "Cardiac"})

    # Test PUT status update
    response = client.put("/incidents/INC_STATUS_1/status", json={"status": "dispatched"})
    assert response.status_code == 200
    data = response.json()
    assert data["incident"]["status"] == "dispatched"

    # Test PATCH status update
    response_patch = client.patch("/incidents/INC_STATUS_1/status", json={"status": "inProgress"})
    assert response_patch.status_code == 200
    assert response_patch.json()["incident"]["status"] == "inProgress"


def test_update_status_invalid_status():
    client.post("/incidents", json={"id": "INC_INVALID_STAT", "category": "medical", "intent": "Cardiac"})
    response = client.put("/incidents/INC_INVALID_STAT/status", json={"status": "invalidStatusName"})
    assert response.status_code == 400


def test_cancel_incident():
    client.post("/incidents", json={"id": "INC_CANCEL_1", "category": "womenSafety", "intent": "Safety Alert"})

    response = client.post("/incidents/INC_CANCEL_1/cancel", json={"reason": "Resolved by citizen"})
    assert response.status_code == 200
    data = response.json()
    assert data["incident"]["status"] == "cancelled"
    assert "Resolved by citizen" in data["incident"]["notes"]


def test_assign_responder():
    client.post("/incidents", json={"id": "INC_RESP_1", "category": "medical", "intent": "Ambulance"})

    payload = {
        "responderId": "R_101",
        "responderName": "City Trauma Care #1",
        "responderPhone": "102",
        "responderType": "Advanced Life Support",
        "estimatedArrivalMinutes": 4,
    }
    response = client.post("/incidents/INC_RESP_1/assign-responder", json=payload)
    assert response.status_code == 200
    data = response.json()
    incident = data["incident"]
    assert incident["assignedResponderId"] == "R_101"
    assert incident["assignedResponderName"] == "City Trauma Care #1"
    assert incident["assignedResponderPhone"] == "102"
    assert incident["estimatedArrivalMinutes"] == 4
