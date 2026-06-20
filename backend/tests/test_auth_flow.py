import os
import tempfile
from pathlib import Path

import pytest

test_db_path = Path(tempfile.gettempdir()) / f"bambootrace-auth-{os.urandom(4).hex()}.db"
os.environ["DATABASE_URL"] = f"sqlite:///{test_db_path.as_posix()}"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-with-enough-entropy-for-tests"
os.environ["ALLOWED_ORIGINS"] = "http://localhost:3000"

from fastapi.testclient import TestClient

from app.core.database import Base, engine
from app.main import app
from app.routers.auth import _login_attempts, _signup_attempts


Base.metadata.create_all(bind=engine)
client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_auth_rate_limits():
    _login_attempts.clear()
    _signup_attempts.clear()


def unique_email(prefix: str) -> str:
    return f"{prefix}-{os.urandom(4).hex()}@example.com"


def signup_payload(email: str, role: str = "customer") -> dict[str, str]:
    return {
        "email": email,
        "password": "StrongPass1",
        "name": "Test User",
        "role": role,
    }


def complete_profile(headers: dict[str, str], role: str = "customer") -> dict:
    response = client.patch(
        "/users/me/profile",
        headers=headers,
        json={
            "phone": "+91 9876543210",
            "addressLine": f"{role.title()} address",
            "city": "Mysuru",
            "district": "Mysuru",
            "state": "Karnataka",
            "pincode": "570001",
        },
    )
    assert response.status_code == 200
    return response.json()


def test_signup_login_me_and_role_protection() -> None:
    email = unique_email("customer")

    signup_response = client.post("/auth/signup", json=signup_payload(email))
    assert signup_response.status_code == 201
    assert signup_response.json()["profileComplete"] is False
    assert signup_response.json()["user"]["profileComplete"] is False
    token = signup_response.json()["access_token"]

    me_response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert me_response.status_code == 200
    assert me_response.json()["email"] == email

    orders_response = client.get(
        "/orders",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert orders_response.status_code == 200

    batches_response = client.get(
        "/batches",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert batches_response.status_code == 403

    logout_without_token = client.post("/auth/logout")
    assert logout_without_token.status_code == 401

    logout_response = client.post(
        "/auth/logout",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert logout_response.status_code == 200


def test_invalid_token_is_rejected() -> None:
    response = client.get(
        "/auth/me",
        headers={"Authorization": "Bearer invalid-token"},
    )

    assert response.status_code == 401


def test_login_password_rejects_oversized_payload() -> None:
    response = client.post(
        "/auth/login",
        json={"email": "oversized@example.com", "password": "a" * 129},
    )

    assert response.status_code == 422


def test_login_rate_limits_repeated_failures() -> None:
    _login_attempts.clear()
    email = unique_email("rate-limit")

    for _ in range(5):
        response = client.post(
            "/auth/login",
            json={"email": email, "password": "WrongPass1"},
        )
        assert response.status_code == 401

    response = client.post(
        "/auth/login",
        json={"email": email, "password": "WrongPass1"},
    )

    assert response.status_code == 429


def test_signup_rate_limits_repeated_attempts() -> None:
    _signup_attempts.clear()

    for _ in range(10):
        response = client.post(
            "/auth/signup",
            json=signup_payload(unique_email("signup-limit")),
        )
        assert response.status_code == 201

    response = client.post(
        "/auth/signup",
        json=signup_payload(unique_email("signup-limit")),
    )

    assert response.status_code == 429


def test_incomplete_profile_is_blocked_from_listing_then_allowed_after_update() -> None:
    email = unique_email("farmer-profile")
    signup_response = client.post("/auth/signup", json=signup_payload(email, "farmer"))
    assert signup_response.status_code == 201
    headers = {"Authorization": f"Bearer {signup_response.json()['access_token']}"}

    blocked = client.post(
        "/batches",
        headers=headers,
        json={
            "batchId": "INCOMPLETE-PROFILE",
            "type": "Moso Bamboo",
            "quantity": 10,
            "location": "Coorg",
        },
    )
    assert blocked.status_code == 428
    assert blocked.json()["detail"]["profileRequired"] is True

    profile = client.patch(
        "/users/me/profile",
        headers=headers,
        json={
            "phone": "+91 9876543210",
            "addressLine": "Farm pickup gate",
            "city": "Coorg",
            "district": "Kodagu",
            "state": "Karnataka",
            "pincode": "571201",
        },
    )
    assert profile.status_code == 200
    assert profile.json()["profileComplete"] is True

    allowed = client.post(
        "/batches",
        headers=headers,
        json={
            "batchId": "COMPLETE-PROFILE",
            "type": "Moso Bamboo",
            "quantity": 10,
            "location": "Coorg",
        },
    )
    assert allowed.status_code == 201


def test_profile_update_requires_all_required_contact_fields() -> None:
    signup_response = client.post(
        "/auth/signup",
        json=signup_payload(unique_email("partial-profile"), "customer"),
    )
    assert signup_response.status_code == 201
    headers = {"Authorization": f"Bearer {signup_response.json()['access_token']}"}

    response = client.patch(
        "/users/me/profile",
        headers=headers,
        json={"phone": "+91 9876543210"},
    )

    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["profileRequired"] is True
    assert "address_line" in detail["missingFields"]
    assert "city" in detail["missingFields"]


def test_incomplete_customer_is_blocked_from_product_order() -> None:
    artisan_signup = client.post(
        "/auth/signup",
        json=signup_payload(unique_email("artisan-product"), "artisan"),
    )
    assert artisan_signup.status_code == 201
    artisan_headers = {
        "Authorization": f"Bearer {artisan_signup.json()['access_token']}"
    }
    complete_profile(artisan_headers, "artisan")
    project = client.post(
        "/projects",
        headers=artisan_headers,
        json={
            "sourceBatchId": "BT-ORDER",
            "productType": "Furniture",
            "productName": "Bamboo Stool",
            "quantity": 2,
            "estimatedDays": 5,
            "progress": 0,
        },
    )
    assert project.status_code == 201

    customer_signup = client.post(
        "/auth/signup",
        json=signup_payload(unique_email("customer-product"), "customer"),
    )
    assert customer_signup.status_code == 201
    customer_headers = {
        "Authorization": f"Bearer {customer_signup.json()['access_token']}"
    }
    blocked = client.post(
        "/orders/product",
        headers=customer_headers,
        json={
            "productId": project.json()["id"],
            "quantity": 1,
            "quantityUnit": "item",
            "fulfillmentType": "pickup",
        },
    )

    assert blocked.status_code == 428
    assert blocked.json()["detail"]["profileRequired"] is True


def test_incomplete_artisan_is_blocked_from_material_order() -> None:
    farmer_signup = client.post(
        "/auth/signup",
        json=signup_payload(unique_email("farmer-material"), "farmer"),
    )
    assert farmer_signup.status_code == 201
    farmer_headers = {
        "Authorization": f"Bearer {farmer_signup.json()['access_token']}"
    }
    complete_profile(farmer_headers, "farmer")
    batch = client.post(
        "/batches",
        headers=farmer_headers,
        json={
            "batchId": "MAT-PROFILE",
            "type": "Green Bamboo",
            "quantityAvailable": 20,
            "quantityUnit": "kg",
            "location": "Sakleshpur",
            "availableNow": True,
        },
    )
    assert batch.status_code == 201

    artisan_signup = client.post(
        "/auth/signup",
        json=signup_payload(unique_email("artisan-material"), "artisan"),
    )
    assert artisan_signup.status_code == 201
    artisan_headers = {
        "Authorization": f"Bearer {artisan_signup.json()['access_token']}"
    }
    blocked = client.post(
        "/orders/material",
        headers=artisan_headers,
        json={
            "batchId": batch.json()["id"],
            "quantity": 5,
            "quantityUnit": "kg",
            "fulfillmentType": "pickup",
        },
    )

    assert blocked.status_code == 428
    assert blocked.json()["detail"]["profileRequired"] is True
