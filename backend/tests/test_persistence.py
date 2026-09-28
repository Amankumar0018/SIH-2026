import os
import sqlite3
import tempfile
import pytest
from fastapi.testclient import TestClient

from app.database import get_connection, init_db
from app.main import app
from app.models import AIIntelligenceModel, EmergencyIncidentModel
from app.security import check_incident_access
from app.store import IncidentStore, UserStore, store, user_store

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_stores():
    store.clear()
    user_store.clear()
    yield
    store.clear()
    user_store.clear()


def test_database_initialization():
    """Verify that all required tables and indexes are initialized automatically."""
    init_db()
    with get_connection() as conn:
        cursor = conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = {row["name"] for row in cursor.fetchall()}
        assert "users" in tables
        assert "tokens" in tables
        assert "incidents" in tables

        # Verify default users seeded automatically
        cursor = conn.execute("SELECT mobileNumber, role FROM users")
        seeded_users = {row["mobileNumber"]: row["role"] for row in cursor.fetchall()}
        assert seeded_users.get("9876543210") == "citizen"
        assert seeded_users.get("9000000000") == "responder"
        assert seeded_users.get("9999999999") == "dual"


def test_user_and_session_persistence_across_instances():
    """Verify that user registration and auth tokens persist across independent store instances."""
    created_user = user_store.create_user(
        mobile="9123456780",
        password="MyPassword123!",
        name="Persistence Test User",
        role="citizen",
        email="test@pukaar.app",
        emergency_contact_name="Emergency Buddy",
        emergency_contact_phone="9888888888",
        blood_group="O+",
        allergies="Peanuts",
        medications="None",
    )
    token = user_store.create_token(created_user.mobileNumber)

    # Simulate application restart by creating a new UserStore instance
    reloaded_user_store = UserStore()

    # User profile persistence check
    fetched_user = reloaded_user_store.get_by_mobile("9123456780")
    assert fetched_user is not None
    assert fetched_user.id == created_user.id
    assert fetched_user.name == "Persistence Test User"
    assert fetched_user.email == "test@pukaar.app"
    assert fetched_user.bloodGroup == "O+"
    assert fetched_user.allergies == "Peanuts"

    # Password verification check across instances
    verified = reloaded_user_store.verify_credentials("9123456780", "MyPassword123!")
    assert verified is not None
    assert verified.id == created_user.id

    # Token lookup persistence check
    token_user = reloaded_user_store.get_user_by_token(token)
    assert token_user is not None
    assert token_user.mobileNumber == "9123456780"

    # Token revocation check
    reloaded_user_store.revoke_token(token)
    assert reloaded_user_store.get_user_by_token(token) is None


def test_incident_persistence_and_lifecycle_across_instances():
    """Verify that emergency incidents, AI intelligence, and lifecycle transitions persist across restarts."""
    incident_id = store.generate_id("medical")
    ai_intel = AIIntelligenceModel(
        summary="Patient exhibiting severe cardiac distress.",
        urgencyScore="CRITICAL_9",
        hazards=["Cardiac arrest risk"],
        recommendedActions=["Dispatch ALS ambulance", "Prepare defibrillator"],
        missingInfo=["Current pulse"],
        confidence=0.92,
    )
    incident = EmergencyIncidentModel(
        id=incident_id,
        userId="9876543210",
        category="medical",
        intent="Heart Attack Symptoms",
        latitude=18.5204,
        longitude=73.8567,
        accuracy=5.0,
        timestamp="2026-09-28T12:00:00Z",
        priority="critical",
        status="created",
        notes="Citizen unconscious on 2nd floor",
        aiIntelligence=ai_intel,
    )
    store.save(incident)

    # Simulate restart 1: fresh IncidentStore instance reads from SQLite
    reloaded_store_1 = IncidentStore()
    retrieved = reloaded_store_1.get_by_id(incident_id)
    assert retrieved is not None
    assert retrieved.id == incident_id
    assert retrieved.status == "created"
    assert retrieved.priority == "critical"
    assert retrieved.aiIntelligence is not None
    assert retrieved.aiIntelligence.urgencyScore == "CRITICAL_9"
    assert retrieved.aiIntelligence.confidence == 0.92

    # Transition status: created -> dispatched
    reloaded_store_1.update_status(incident_id, "dispatched")

    # Simulate restart 2: fresh IncidentStore verifies status transition persisted
    reloaded_store_2 = IncidentStore()
    retrieved_2 = reloaded_store_2.get_by_id(incident_id)
    assert retrieved_2 is not None
    assert retrieved_2.status == "dispatched"

    # Assign responder
    reloaded_store_2.assign_responder(
        incident_id=incident_id,
        responder_id="RESP_PUNE_01",
        responder_name="Paramedic Rao",
        responder_phone="108",
        responder_type="Ambulance",
        responder_lat=18.5220,
        responder_lng=73.8580,
        eta_minutes=4,
    )

    # Simulate restart 3: verify assigned responder data persisted
    reloaded_store_3 = IncidentStore()
    retrieved_3 = reloaded_store_3.get_by_id(incident_id)
    assert retrieved_3 is not None
    assert retrieved_3.assignedResponderId == "RESP_PUNE_01"
    assert retrieved_3.assignedResponderName == "Paramedic Rao"
    assert retrieved_3.assignedResponderPhone == "108"
    assert retrieved_3.estimatedArrivalMinutes == 4
    assert retrieved_3.responderLatitude == 18.5220

    # Cancel with reason
    reloaded_store_3.cancel(incident_id, reason="False alarm by family member")

    # Simulate restart 4: verify cancellation persisted
    reloaded_store_4 = IncidentStore()
    retrieved_4 = reloaded_store_4.get_by_id(incident_id)
    assert retrieved_4 is not None
    assert retrieved_4.status == "cancelled"
    assert "False alarm by family member" in (retrieved_4.notes or "")


def test_ownership_and_rbac_persistence():
    """Verify citizen ownership rules and responder authorization behave identically after restart."""
    incident_id = store.generate_id("campus")
    incident = EmergencyIncidentModel(
        id=incident_id,
        userId="9876543210",
        category="campus",
        intent="Lab Safety Hazard",
        timestamp="2026-09-28T12:00:00Z",
        priority="high",
        status="created",
    )
    store.save(incident)

    # Re-instantiate stores to simulate restart
    fresh_user_store = UserStore()
    fresh_incident_store = IncidentStore()

    citizen_owner = fresh_user_store.get_by_mobile("9876543210")
    other_citizen = fresh_user_store.create_user(
        mobile="9888877777",
        password="password123",
        name="Other Citizen",
        role="citizen",
    )
    responder = fresh_user_store.get_by_mobile("9000000000")

    inc = fresh_incident_store.get_by_id(incident_id)
    assert inc is not None

    # Owner citizen can access
    assert check_incident_access(citizen_owner, inc.userId) is True
    # Other citizen cannot access
    assert check_incident_access(other_citizen, inc.userId) is False
    # Responder can access
    assert check_incident_access(responder, inc.userId) is True


def test_end_to_end_api_lifecycle_with_restart():
    """End-to-end REST API verification: register, create incident, restart backend stores, verify & update."""
    # 1. Register a citizen
    reg_res = client.post(
        "/auth/register",
        json={
            "mobileNumber": "9777766666",
            "password": "Password99!",
            "name": "E2E Citizen",
            "role": "citizen",
        },
    )
    assert reg_res.status_code == 201
    citizen_token = reg_res.json()["accessToken"]
    citizen_headers = {"Authorization": f"Bearer {citizen_token}"}

    # 2. Citizen creates incident
    inc_res = client.post(
        "/incidents",
        headers=citizen_headers,
        json={
            "category": "disaster",
            "intent": "Flash Flood Trapped Citizen",
            "latitude": 18.5300,
            "longitude": 73.8500,
            "priority": "critical",
            "notes": "Water level rising rapidly",
        },
    )
    assert inc_res.status_code == 201
    incident_id = inc_res.json()["incident"]["id"]

    # 3. Simulate backend restart: create new store singletons
    new_u_store = UserStore()
    new_i_store = IncidentStore()

    # Verify citizen token is still valid through API
    me_res = client.get("/auth/me", headers=citizen_headers)
    assert me_res.status_code == 200
    assert me_res.json()["user"]["mobileNumber"] == "9777766666"

    # Verify citizen can fetch their incident
    get_res = client.get(f"/incidents/{incident_id}", headers=citizen_headers)
    assert get_res.status_code == 200
    assert get_res.json()["incident"]["id"] == incident_id
    assert get_res.json()["incident"]["status"] == "created"

    # 4. Responder logs in and transitions incident
    resp_login = client.post(
        "/auth/login",
        json={"mobileNumber": "9000000000", "password": "responder123"},
    )
    assert resp_login.status_code == 200
    responder_token = resp_login.json()["accessToken"]
    responder_headers = {"Authorization": f"Bearer {responder_token}"}

    # Responder views active feed
    active_res = client.get("/incidents/active", headers=responder_headers)
    assert active_res.status_code == 200
    active_ids = [i["id"] for i in active_res.json()["incidents"]]
    assert incident_id in active_ids

    # Responder updates status to inProgress
    update_res = client.put(
        f"/incidents/{incident_id}/status",
        headers=responder_headers,
        json={"status": "inProgress"},
    )
    assert update_res.status_code == 200
    assert update_res.json()["incident"]["status"] == "inProgress"

    # Another restart simulation
    another_store = IncidentStore()
    after_restart = another_store.get_by_id(incident_id)
    assert after_restart is not None
    assert after_restart.status == "inProgress"
