import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.store import store, user_store

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_stores():
    store.clear()
    user_store.clear()
    yield
    store.clear()
    user_store.clear()


def test_citizen_login_success():
    response = client.post(
        "/auth/login",
        json={"mobileNumber": "9876543210", "password": "password123"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "citizen"
    assert data["mobileNumber"] == "9876543210"
    assert data["accessToken"].startswith("pukaar_token_")


def test_responder_login_success():
    response = client.post(
        "/auth/login",
        json={"mobileNumber": "9000000000", "password": "responder123"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "responder"
    assert data["mobileNumber"] == "9000000000"
    assert data["accessToken"].startswith("pukaar_token_")


def test_dual_role_login_success():
    response = client.post(
        "/auth/login",
        json={"mobileNumber": "9999999999", "password": "dual123"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "dual"
    assert data["mobileNumber"] == "9999999999"
    assert data["accessToken"].startswith("pukaar_token_")


def test_login_invalid_credentials():
    response = client.post(
        "/auth/login",
        json={"mobileNumber": "9876543210", "password": "wrong_password"},
    )
    assert response.status_code == 401
    assert "invalid" in response.json()["detail"].lower()


def test_register_new_user_dual_role():
    payload = {
        "mobileNumber": "9123456789",
        "password": "newpassword123",
        "name": "New Dual User",
        "role": "dual",
        "emergencyContactName": "Parent",
        "emergencyContactPhone": "9876543210",
    }
    response = client.post("/auth/register", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["role"] == "dual"
    assert data["mobileNumber"] == "9123456789"
    assert data["accessToken"].startswith("pukaar_token_")


def test_register_duplicate_mobile():
    payload = {
        "mobileNumber": "9876543210",
        "password": "newpassword123",
        "name": "Duplicate User",
    }
    response = client.post("/auth/register", json=payload)
    assert response.status_code == 400
    assert "already exists" in response.json()["detail"].lower()


def test_protected_endpoint_without_auth():
    response = client.get("/incidents/active")
    assert response.status_code == 401
    assert "missing authentication" in response.json()["detail"].lower()


def test_protected_endpoint_with_invalid_token():
    headers = {"Authorization": "Bearer invalid_fake_token"}
    response = client.get("/incidents/active", headers=headers)
    assert response.status_code == 401
    assert "invalid or expired" in response.json()["detail"].lower()


def test_responder_endpoint_with_citizen_role_forbidden():
    # Login as citizen
    c_res = client.post("/auth/login", json={"mobileNumber": "9876543210", "password": "password123"})
    c_token = c_res.json()["accessToken"]

    headers = {"Authorization": f"Bearer {c_token}"}
    response = client.get("/incidents/active", headers=headers)
    assert response.status_code == 403
    assert "forbidden" in response.json()["detail"].lower()


def test_responder_endpoint_with_responder_role_success():
    # Login as responder
    r_res = client.post("/auth/login", json={"mobileNumber": "9000000000", "password": "responder123"})
    r_token = r_res.json()["accessToken"]

    headers = {"Authorization": f"Bearer {r_token}"}
    response = client.get("/incidents/active", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "incidents" in data


def test_responder_endpoint_with_dual_role_success():
    # Login as dual role
    d_res = client.post("/auth/login", json={"mobileNumber": "9999999999", "password": "dual123"})
    d_token = d_res.json()["accessToken"]

    headers = {"Authorization": f"Bearer {d_token}"}
    response = client.get("/incidents/active", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "incidents" in data


def test_get_current_user_profile():
    c_res = client.post("/auth/login", json={"mobileNumber": "9876543210", "password": "password123"})
    c_token = c_res.json()["accessToken"]

    headers = {"Authorization": f"Bearer {c_token}"}
    response = client.get("/auth/me", headers=headers)
    assert response.status_code == 200
    user_data = response.json()["user"]
    assert user_data["mobileNumber"] == "9876543210"
    assert user_data["role"] == "citizen"


def test_logout_revokes_token():
    # Login to obtain token
    c_res = client.post("/auth/login", json={"mobileNumber": "9876543210", "password": "password123"})
    c_token = c_res.json()["accessToken"]

    headers = {"Authorization": f"Bearer {c_token}"}
    
    # Confirm token is valid
    me_res = client.get("/auth/me", headers=headers)
    assert me_res.status_code == 200

    # Logout
    logout_res = client.post("/auth/logout", headers=headers)
    assert logout_res.status_code == 200
    assert logout_res.json()["status"] == "success"

    # Confirm token is now revoked and returns 401
    me_after_res = client.get("/auth/me", headers=headers)
    assert me_after_res.status_code == 401

