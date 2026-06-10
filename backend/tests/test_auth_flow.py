import os
import tempfile
from pathlib import Path

test_db_path = Path(tempfile.gettempdir()) / f"bambootrace-auth-{os.urandom(4).hex()}.db"
os.environ["DATABASE_URL"] = f"sqlite:///{test_db_path.as_posix()}"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-with-enough-entropy-for-tests"
os.environ["ALLOWED_ORIGINS"] = "http://localhost:3000"

from fastapi.testclient import TestClient

from app.core.database import Base, engine
from app.main import app
from app.routers.auth import _login_attempts


Base.metadata.create_all(bind=engine)
client = TestClient(app)


def unique_email(prefix: str) -> str:
    return f"{prefix}-{os.urandom(4).hex()}@example.com"


def signup_payload(email: str, role: str = "customer") -> dict[str, str]:
    return {
        "email": email,
        "password": "StrongPass1",
        "name": "Test User",
        "role": role,
    }


def test_signup_login_me_and_role_protection() -> None:
    email = unique_email("customer")

    signup_response = client.post("/auth/signup", json=signup_payload(email))
    assert signup_response.status_code == 201
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
