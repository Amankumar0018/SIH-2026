import json
import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.main import app
from app.store import store, user_store
from app.ws import connection_manager


@pytest.fixture(autouse=True)
def reset_stores():
    store.clear()
    user_store.clear()
    connection_manager.active_connections.clear()
    yield
    store.clear()
    user_store.clear()
    connection_manager.active_connections.clear()


def test_ws_connection_rejected_without_token():
    client = TestClient(app)
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect("/ws") as ws:
            pass
    assert exc_info.value.code == 1008


def test_ws_connection_rejected_with_invalid_token():
    client = TestClient(app)
    with pytest.raises(WebSocketDisconnect) as exc_info:
        with client.websocket_connect("/ws?token=invalid_token_123") as ws:
            pass
    assert exc_info.value.code == 1008


def test_ws_connection_accepted_with_valid_citizen_token():
    client = TestClient(app)
    token = user_store.create_token("9876543210")
    with client.websocket_connect(f"/ws?token={token}") as ws:
        assert len(connection_manager.active_connections) == 1
    # After exit context, connection is cleaned up
    assert len(connection_manager.active_connections) == 0


def test_ws_connection_accepted_with_whitespace_token():
    client = TestClient(app)
    token = user_store.create_token("9876543210")
    # Test whitespace around token query parameter
    with client.websocket_connect(f"/ws?token=%20{token}%20") as ws:
        assert len(connection_manager.active_connections) == 1
    assert len(connection_manager.active_connections) == 0

def test_ws_with_origin_header():
    client = TestClient(app)
    token = user_store.create_token("9876543210")
    try:
        with client.websocket_connect(f"/ws?token={token}", headers={"Origin": "http://localhost"}) as ws:
            pass
    except Exception as e:
        print("Exception:", e)
        raise


def test_ws_connection_accepted_with_valid_responder_token():
    client = TestClient(app)
    token = user_store.create_token("9000000000")
    with client.websocket_connect(f"/ws?token={token}") as ws:
        assert len(connection_manager.active_connections) == 1
    assert len(connection_manager.active_connections) == 0


def test_ws_incident_created_delivered_to_responder_and_citizen():
    client = TestClient(app)
    citizen_token = user_store.create_token("9876543210")
    responder_token = user_store.create_token("9000000000")

    with client.websocket_connect(f"/ws?token={responder_token}") as responder_ws:
        with client.websocket_connect(f"/ws?token={citizen_token}") as citizen_ws:
            # Citizen creates incident via HTTP POST
            post_resp = client.post(
                "/incidents",
                json={
                    "category": "medical",
                    "intent": "Severe Bleeding",
                    "latitude": 28.61,
                    "longitude": 77.20,
                },
                headers={"Authorization": f"Bearer {citizen_token}"},
            )
            assert post_resp.status_code == 201
            created_id = post_resp.json()["incident"]["id"]

            # Responder should receive incident.created event
            resp_msg = responder_ws.receive_text()
            resp_data = json.loads(resp_msg)
            assert resp_data["type"] == "incident.created"
            assert resp_data["incident"]["id"] == created_id
            assert resp_data["incident"]["category"] == "medical"

            # Citizen should receive incident.created event
            citizen_msg = citizen_ws.receive_text()
            cit_data = json.loads(citizen_msg)
            assert cit_data["type"] == "incident.created"
            assert cit_data["incident"]["id"] == created_id


def test_ws_citizen_isolation_no_unrelated_incident_delivered():
    client = TestClient(app)
    citizen_a_token = user_store.create_token("9876543210")
    
    # Create second citizen
    user_store.create_user(mobile="9111111111", password="password123", name="Citizen B")
    citizen_b_token = user_store.create_token("9111111111")
    responder_token = user_store.create_token("9000000000")

    with client.websocket_connect(f"/ws?token={responder_token}") as responder_ws:
        with client.websocket_connect(f"/ws?token={citizen_b_token}") as citizen_b_ws:
            # Citizen A creates incident
            post_resp = client.post(
                "/incidents",
                json={
                    "category": "womenSafety",
                    "intent": "Unsafe Situation",
                },
                headers={"Authorization": f"Bearer {citizen_a_token}"},
            )
            assert post_resp.status_code == 201
            created_id = post_resp.json()["incident"]["id"]

            # Responder gets the event
            resp_msg = responder_ws.receive_text()
            resp_data = json.loads(resp_msg)
            assert resp_data["incident"]["id"] == created_id

            # Citizen B should NOT receive Citizen A's incident
            # Create an incident for Citizen B to verify Citizen B's WS is working
            post_resp_b = client.post(
                "/incidents",
                json={
                    "category": "medical",
                    "intent": "Injury",
                },
                headers={"Authorization": f"Bearer {citizen_b_token}"},
            )
            assert post_resp_b.status_code == 201
            b_created_id = post_resp_b.json()["incident"]["id"]

            cit_b_msg = citizen_b_ws.receive_text()
            cit_b_data = json.loads(cit_b_msg)
            # The FIRST event Citizen B receives is their OWN incident, NOT Citizen A's
            assert cit_b_data["incident"]["id"] == b_created_id
            assert cit_b_data["incident"]["id"] != created_id


def test_ws_status_update_and_assignment_delivered_in_realtime():
    client = TestClient(app)
    citizen_token = user_store.create_token("9876543210")
    responder_token = user_store.create_token("9000000000")

    with client.websocket_connect(f"/ws?token={responder_token}") as responder_ws:
        with client.websocket_connect(f"/ws?token={citizen_token}") as citizen_ws:
            # 1. Create incident
            post_resp = client.post(
                "/incidents",
                json={"category": "disaster", "intent": "Fire Emergency"},
                headers={"Authorization": f"Bearer {citizen_token}"},
            )
            inc_id = post_resp.json()["incident"]["id"]
            responder_ws.receive_text()  # drain created
            citizen_ws.receive_text()    # drain created

            # 2. Responder assigns themselves
            assign_resp = client.post(
                f"/incidents/{inc_id}/assign-responder",
                json={
                    "responderId": "RESP_001",
                    "responderName": "Rescue Patrol Alpha",
                    "responderPhone": "1070",
                    "estimatedArrivalMinutes": 4,
                },
                headers={"Authorization": f"Bearer {responder_token}"},
            )
            assert assign_resp.status_code == 200

            resp_msg = json.loads(responder_ws.receive_text())
            cit_msg = json.loads(citizen_ws.receive_text())
            assert resp_msg["type"] == "incident.updated"
            assert resp_msg["incident"]["assignedResponderName"] == "Rescue Patrol Alpha"
            assert cit_msg["type"] == "incident.updated"
            assert cit_msg["incident"]["assignedResponderName"] == "Rescue Patrol Alpha"
            assert cit_msg["incident"]["estimatedArrivalMinutes"] == 4

            # 3. Update status to inProgress
            status_resp = client.put(
                f"/incidents/{inc_id}/status",
                json={"status": "inProgress"},
                headers={"Authorization": f"Bearer {responder_token}"},
            )
            assert status_resp.status_code == 200

            cit_update = json.loads(citizen_ws.receive_text())
            assert cit_update["type"] == "incident.updated"
            assert cit_update["incident"]["status"] == "inProgress"


def test_ws_no_event_emitted_when_mutation_fails():
    client = TestClient(app)
    responder_token = user_store.create_token("9000000000")
    citizen_token = user_store.create_token("9876543210")

    with client.websocket_connect(f"/ws?token={responder_token}") as responder_ws:
        # Invalid status update on non-existent incident
        bad_resp = client.put(
            "/incidents/NON_EXISTENT_ID/status",
            json={"status": "accepted"},
            headers={"Authorization": f"Bearer {responder_token}"},
        )
        assert bad_resp.status_code == 404

        # Valid create to verify stream is responsive
        create_resp = client.post(
            "/incidents",
            json={"category": "medical", "intent": "Test"},
            headers={"Authorization": f"Bearer {citizen_token}"},
        )
        assert create_resp.status_code == 201

        # The only event in queue must be the successful create
        event = json.loads(responder_ws.receive_text())
        assert event["type"] == "incident.created"
        assert event["incident"]["id"] == create_resp.json()["incident"]["id"]
