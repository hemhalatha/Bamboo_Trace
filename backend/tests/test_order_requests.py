import os
import tempfile
from datetime import datetime, timedelta, timezone
from io import BytesIO
from pathlib import Path

import pytest

os.environ["DATABASE_URL"] = (
    f"sqlite:///{(Path(tempfile.gettempdir()) / f'bambootrace-requests-{os.urandom(4).hex()}.db').as_posix()}"
)
os.environ["JWT_SECRET_KEY"] = "test-secret-key-with-enough-entropy-for-requests"
os.environ["ALLOWED_ORIGINS"] = "http://localhost:3000"

from fastapi.testclient import TestClient

from app.core.database import Base, SessionLocal, engine
from app.main import app
from app.models import Order
from app.routers.auth import _login_attempts, _signup_attempts


Base.metadata.create_all(bind=engine)
client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_auth_rate_limits():
    _login_attempts.clear()
    _signup_attempts.clear()


def signup(role: str) -> tuple[dict, dict[str, str]]:
    email = f"{role}-{os.urandom(4).hex()}@example.com"
    response = client.post(
        "/auth/signup",
        json={
            "email": email,
            "password": "StrongPass1",
            "name": f"{role.title()} User",
            "role": role,
        },
    )
    assert response.status_code == 201
    data = response.json()
    headers = {"Authorization": f"Bearer {data['access_token']}"}
    profile_response = client.patch(
        "/users/me/profile",
        headers=headers,
        json={
            "phone": "+91 9876543210",
            "addressLine": f"{role.title()} location",
            "city": "Mysuru",
            "district": "Mysuru",
            "state": "Karnataka",
            "pincode": "570001",
        },
    )
    assert profile_response.status_code == 200
    return profile_response.json(), headers


def create_project(headers: dict[str, str]) -> dict:
    response = client.post(
        "/projects",
        headers=headers,
        json={
            "sourceBatchId": "BT-001",
            "productType": "Furniture",
            "productName": "Bamboo Chair",
            "quantity": 5,
            "estimatedDays": 7,
            "progress": 0,
            "status": "available",
        },
    )
    assert response.status_code == 201
    project = response.json()
    assert project["status"] == "available"
    return project


def test_artisan_product_listing_allows_optional_batch_and_material_metadata() -> None:
    _artisan, artisan_headers = signup("artisan")

    response = client.post(
        "/projects",
        headers=artisan_headers,
        json={
            "productName": "Handwoven Bamboo Basket",
            "description": "A sturdy basket made with locally sourced bamboo.",
            "price": 1250,
            "bambooType": "Thorny Bamboo",
            "materialSource": "External Purchase",
            "sourceDetails": "Bought from village market",
            "status": "draft",
        },
    )

    assert response.status_code == 201
    product = response.json()
    assert product["sourceBatchId"] is None
    assert product["description"] == "A sturdy basket made with locally sourced bamboo."
    assert product["price"] == 1250
    assert product["bambooType"] == "Thorny Bamboo"
    assert product["materialSource"] == "External Purchase"
    assert product["sourceDetails"] == "Bought from village market"
    assert product["status"] == "draft"

    publish_response = client.patch(
        f"/projects/{product['id']}",
        headers=artisan_headers,
        json={"status": "available"},
    )

    assert publish_response.status_code == 200
    assert publish_response.json()["status"] == "available"


def create_batch(headers: dict[str, str]) -> dict:
    response = client.post(
        "/batches",
        headers=headers,
        json={
            "batchId": "BATCH-001",
            "type": "Moso Bamboo",
            "quantity": 25,
            "location": "Coorg",
        },
    )
    assert response.status_code == 201
    return response.json()


def notification_titles(headers: dict[str, str]) -> list[str]:
    response = client.get("/notifications", headers=headers)
    assert response.status_code == 200
    return [notification["title"] for notification in response.json()]


def png_bytes() -> bytes:
    return b"\x89PNG\r\n\x1a\n" + b"\x00" * 32


def create_product_order_for_test(
    customer_headers: dict[str, str],
    artisan_headers: dict[str, str],
) -> dict:
    project = create_project(artisan_headers)
    response = client.post(
        "/orders/product",
        headers=customer_headers,
        json={
            "productId": project["id"],
            "quantity": 1,
            "quantityUnit": "item",
            "fulfillmentType": "pickup",
        },
    )
    assert response.status_code == 201
    return response.json()


def create_material_order_for_test(
    artisan_headers: dict[str, str],
    farmer_headers: dict[str, str],
) -> dict:
    batch = create_batch(farmer_headers)
    response = client.post(
        "/orders/material",
        headers=artisan_headers,
        json={
            "batchId": batch["id"],
            "quantity": 1,
            "quantityUnit": "kg",
            "fulfillmentType": "pickup",
        },
    )
    assert response.status_code == 201
    return response.json()


def test_customer_request_accept_creates_order_and_notifications() -> None:
    customer, customer_headers = signup("customer")
    artisan, artisan_headers = signup("artisan")
    project = create_project(artisan_headers)

    request_response = client.post(
        "/order-requests",
        headers=customer_headers,
        json={
            "requestType": "customer_to_artisan",
            "receiverId": artisan["id"],
            "productId": project["id"],
            "quantity": 2,
            "quantityUnit": "item",
            "notes": "Please use a natural finish.",
        },
    )
    assert request_response.status_code == 201
    request_data = request_response.json()
    assert request_data["productId"] == project["id"]
    assert request_data["quantity"] == 2

    duplicate_response = client.post(
        "/order-requests",
        headers=customer_headers,
        json={
            "requestType": "customer_to_artisan",
            "receiverId": artisan["id"],
            "productId": project["id"],
            "quantity": 2,
            "quantityUnit": "item",
        },
    )
    assert duplicate_response.status_code == 409

    active_response = client.get("/order-requests/active", headers=artisan_headers)
    assert active_response.status_code == 200
    assert len(active_response.json()) == 1

    accept_response = client.post(
        f"/order-requests/{request_data['id']}/accept",
        headers=artisan_headers,
    )
    assert accept_response.status_code == 200
    assert accept_response.json()["status"] == "accepted"

    history_response = client.get("/order-requests/history", headers=customer_headers)
    assert history_response.status_code == 200
    assert len(history_response.json()) == 1

    customer_orders = client.get("/orders", headers=customer_headers)
    artisan_orders = client.get("/orders", headers=artisan_headers)
    assert customer_orders.status_code == 200
    assert artisan_orders.status_code == 200
    assert len(customer_orders.json()) == 1
    assert len(artisan_orders.json()) == 1
    order = customer_orders.json()[0]
    assert order["customerId"] == customer["id"]
    assert order["artisanId"] == artisan["id"]
    assert order["productId"] == project["id"]
    assert order["status"] == "accepted"

    notifications = client.get("/notifications", headers=customer_headers)
    assert notifications.status_code == 200
    assert notifications.json()[0]["navigationTarget"] == f"/orders/{order['id']}"


def test_empty_order_lists_load_for_all_roles() -> None:
    for role in ["customer", "artisan", "farmer"]:
        _, headers = signup(role)
        response = client.get("/orders", headers=headers)

        assert response.status_code == 200
        assert response.json() == []


def test_dashboard_stats_are_role_scoped_and_match_records() -> None:
    customer, customer_headers = signup("customer")
    artisan, artisan_headers = signup("artisan")
    farmer, farmer_headers = signup("farmer")

    product = create_project(artisan_headers)
    product_order = client.post(
        "/orders/product",
        headers=customer_headers,
        json={
            "productId": product["id"],
            "quantity": 1,
            "quantityUnit": "item",
            "fulfillmentType": "pickup",
        },
    )
    assert product_order.status_code == 201

    custom_request = client.post(
        "/custom-order-requests",
        headers=customer_headers,
        json={
            "targetArtisanId": artisan["id"],
            "title": "Custom bamboo stool",
            "description": "Small custom stool.",
            "quantity": 1,
        },
    )
    assert custom_request.status_code == 201

    batch = create_batch(farmer_headers)
    material_order = client.post(
        "/orders/material",
        headers=artisan_headers,
        json={
            "batchId": batch["id"],
            "quantity": 1,
            "quantityUnit": "kg",
            "fulfillmentType": "pickup",
        },
    )
    assert material_order.status_code == 201

    customer_stats = client.get("/dashboard/stats", headers=customer_headers)
    artisan_stats = client.get("/dashboard/stats", headers=artisan_headers)
    farmer_stats = client.get("/dashboard/stats", headers=farmer_headers)

    assert customer_stats.status_code == 200
    assert customer_stats.json()["role"] == "customer"
    assert customer_stats.json()["totalOrders"] == 1
    assert customer_stats.json()["activeOrders"] == 1
    assert customer_stats.json()["customRequests"] == 1
    assert customer_stats.json()["activeCustomRequests"] == 1

    assert artisan_stats.status_code == 200
    assert artisan_stats.json()["role"] == "artisan"
    assert artisan_stats.json()["productOrdersReceived"] == 1
    assert artisan_stats.json()["materialOrdersPlaced"] == 1
    assert artisan_stats.json()["productsListed"] == 1
    assert artisan_stats.json()["customRequests"] == 1
    assert artisan_stats.json()["activeCustomRequests"] == 1

    assert farmer_stats.status_code == 200
    assert farmer_stats.json()["role"] == "farmer"
    assert farmer_stats.json()["materialOrdersReceived"] == 1
    assert farmer_stats.json()["activeMaterialOrders"] == 1
    assert farmer_stats.json()["batchesListed"] == 1
    assert farmer_stats.json()["activeBatches"] == 1


def test_users_can_save_profile_details_for_each_role() -> None:
    for role in ["customer", "artisan", "farmer"]:
        _, headers = signup(role)

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
                "landmark": "Market road",
            },
        )

        assert response.status_code == 200
        profile = response.json()
        assert profile["phone"] == "+91 9876543210"
        assert profile["addressLine"] == f"{role.title()} address"
        assert profile["city"] == "Mysuru"


def test_marketplace_shows_public_location_and_orders_show_contact_details() -> None:
    _, customer_headers = signup("customer")
    _, artisan_headers = signup("artisan")
    _, farmer_headers = signup("farmer")

    artisan_profile = client.patch(
        "/users/me/profile",
        headers=artisan_headers,
        json={
            "phone": "+91 9000000001",
            "addressLine": "Workshop 12",
            "city": "Channapatna",
            "district": "Ramanagara",
            "state": "Karnataka",
            "pincode": "562160",
        },
    )
    farmer_profile = client.patch(
        "/users/me/profile",
        headers=farmer_headers,
        json={
            "phone": "+91 9000000002",
            "addressLine": "Farm gate",
            "city": "Sakleshpur",
            "district": "Hassan",
            "state": "Karnataka",
            "pincode": "573134",
        },
    )
    assert artisan_profile.status_code == 200
    assert farmer_profile.status_code == 200

    project = create_project(artisan_headers)
    batch = create_batch(farmer_headers)

    product_catalog = client.get("/projects/catalog", headers=customer_headers)
    assert product_catalog.status_code == 200
    catalog_product = next(
        item for item in product_catalog.json() if item["id"] == project["id"]
    )
    assert catalog_product["artisanLocation"] == "Channapatna, Ramanagara"
    assert "phone" not in catalog_product
    assert "addressLine" not in catalog_product

    batch_catalog = client.get("/batches/catalog", headers=artisan_headers)
    assert batch_catalog.status_code == 200
    catalog_batch = next(item for item in batch_catalog.json() if item["id"] == batch["id"])
    assert catalog_batch["farmerLocation"] == "Sakleshpur, Hassan"
    assert "phone" not in catalog_batch
    assert "addressLine" not in catalog_batch

    order_response = client.post(
        "/orders/product",
        headers=customer_headers,
        json={
            "productId": project["id"],
            "quantity": 1,
            "quantityUnit": "item",
            "fulfillmentType": "pickup",
        },
    )
    assert order_response.status_code == 201
    order = order_response.json()

    customer_orders = client.get("/orders", headers=customer_headers)
    assert customer_orders.status_code == 200
    order = customer_orders.json()[0]
    assert order["artisan"]["phone"] == "+91 9000000001"
    assert order["artisan"]["addressLine"] == "Workshop 12"


def test_customer_can_place_direct_product_order_for_artisan_product() -> None:
    customer, customer_headers = signup("customer")
    artisan, artisan_headers = signup("artisan")
    project = create_project(artisan_headers)

    order_response = client.post(
        "/orders/product",
        headers=customer_headers,
        json={
            "productId": project["id"],
            "quantity": 2,
            "quantityUnit": "item",
            "fulfillmentType": "delivery",
        },
    )

    assert order_response.status_code == 201
    order = order_response.json()
    assert order["customerId"] == customer["id"]
    assert order["artisanId"] == artisan["id"]
    assert order["productId"] == project["id"]
    assert order["orderType"] == "product_order"
    assert order["fulfillmentType"] == "delivery"

    customer_orders = client.get("/orders", headers=customer_headers)
    artisan_orders = client.get("/orders", headers=artisan_headers)
    assert customer_orders.status_code == 200
    assert artisan_orders.status_code == 200
    assert len(customer_orders.json()) == 1
    assert len(artisan_orders.json()) == 1
    artisan_notifications = client.get("/notifications", headers=artisan_headers)
    assert artisan_notifications.status_code == 200
    assert artisan_notifications.json()[0]["type"] == "request_created"
    assert artisan_notifications.json()[0]["entityType"] == "order"
    assert artisan_notifications.json()[0]["entityId"] == order["id"]
    assert artisan_notifications.json()[0]["navigationTarget"] == f"/orders/{order['id']}"


def test_artisan_can_update_only_owned_project_status() -> None:
    _, artisan_headers = signup("artisan")
    _, other_artisan_headers = signup("artisan")
    project = create_project(artisan_headers)

    forbidden_response = client.patch(
        f"/projects/{project['id']}",
        headers=other_artisan_headers,
        json={"status": "sold"},
    )
    assert forbidden_response.status_code == 404

    update_response = client.patch(
        f"/projects/{project['id']}",
        headers=artisan_headers,
        json={
            "productName": "Updated Bamboo Chair",
            "quantity": 4,
            "status": "draft",
        },
    )
    assert update_response.status_code == 200
    updated = update_response.json()
    assert updated["productName"] == "Updated Bamboo Chair"
    assert updated["quantity"] == 4
    assert updated["status"] == "draft"
    assert updated["isHidden"] is True

    available_response = client.patch(
        f"/projects/{project['id']}",
        headers=artisan_headers,
        json={"status": "available"},
    )
    assert available_response.status_code == 200
    assert available_response.json()["status"] == "available"
    assert available_response.json()["isHidden"] is False


def test_product_order_marks_project_ordered_and_blocks_second_order() -> None:
    _, customer_headers = signup("customer")
    _, artisan_headers = signup("artisan")
    project = create_project(artisan_headers)

    order_response = client.post(
        "/orders/product",
        headers=customer_headers,
        json={
            "productId": project["id"],
            "quantity": 2,
            "quantityUnit": "item",
            "fulfillmentType": "pickup",
        },
    )
    assert order_response.status_code == 201
    order = order_response.json()

    projects_response = client.get("/projects", headers=artisan_headers)
    assert projects_response.status_code == 200
    updated_project = next(
        item for item in projects_response.json() if item["id"] == project["id"]
    )
    assert updated_project["quantity"] == 3
    assert updated_project["status"] == "ordered"

    catalog_response = client.get("/projects/catalog", headers=customer_headers)
    assert catalog_response.status_code == 200
    catalog_project = next(
        item for item in catalog_response.json() if item["id"] == project["id"]
    )
    assert catalog_project["status"] == "ordered"

    second_order = client.post(
        "/orders/product",
        headers=customer_headers,
        json={
            "productId": project["id"],
            "quantity": 1,
            "quantityUnit": "item",
            "fulfillmentType": "pickup",
        },
    )
    assert second_order.status_code == 400

    otp_response = client.post(
        f"/orders/{order['id']}/generate-handover-otp",
        headers=customer_headers,
    )
    assert otp_response.status_code == 200
    verify_response = client.post(
        f"/orders/{order['id']}/verify-handover-otp",
        headers=artisan_headers,
        json={"otp": otp_response.json()["otp"]},
    )
    assert verify_response.status_code == 200
    assert verify_response.json()["status"] == "completed"
    assert verify_response.json()["fulfillmentStatus"] == "received"

    completed_projects = client.get("/projects", headers=artisan_headers)
    assert completed_projects.status_code == 200
    completed_project = next(
        item for item in completed_projects.json() if item["id"] == project["id"]
    )
    assert completed_project["status"] == "sold"


def test_direct_product_order_rejects_out_of_stock_quantity() -> None:
    _, customer_headers = signup("customer")
    _, artisan_headers = signup("artisan")
    project = create_project(artisan_headers)

    response = client.post(
        "/orders/product",
        headers=customer_headers,
        json={
            "productId": project["id"],
            "quantity": project["quantity"] + 1,
            "quantityUnit": "item",
            "fulfillmentType": "pickup",
        },
    )

    assert response.status_code == 400


def test_authenticated_user_can_upload_image_and_read_static_file() -> None:
    _, headers = signup("artisan")

    response = client.post(
        "/uploads/images",
        headers=headers,
        files={"file": ("listing.png", BytesIO(png_bytes()), "image/png")},
    )

    assert response.status_code == 201
    image_url = response.json()["imageUrl"]
    assert image_url.startswith("/static/uploads/")

    static_response = client.get(image_url)
    assert static_response.status_code == 200
    assert static_response.content == png_bytes()
    assert static_response.headers["x-content-type-options"] == "nosniff"


def test_image_upload_rejects_mismatched_file_signature() -> None:
    _, headers = signup("artisan")

    response = client.post(
        "/uploads/images",
        headers=headers,
        files={"file": ("listing.png", BytesIO(b"not-a-png"), "image/png")},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == (
        "Uploaded file does not match the selected image type"
    )


def test_image_upload_rejects_unsafe_extension() -> None:
    _, headers = signup("artisan")

    response = client.post(
        "/uploads/images",
        headers=headers,
        files={"file": ("listing.svg", BytesIO(b"<svg></svg>"), "image/svg+xml")},
    )

    assert response.status_code == 400

def test_image_urls_are_persisted_for_listings_and_custom_requests() -> None:
    customer, customer_headers = signup("customer")
    artisan, artisan_headers = signup("artisan")
    _, farmer_headers = signup("farmer")

    product_response = client.post(
        "/projects",
        headers=artisan_headers,
        json={
            "sourceBatchId": "IMG-BT-001",
            "productType": "Furniture",
            "productName": "Bamboo Bench",
            "quantity": 3,
            "estimatedDays": 5,
            "progress": 0,
            "imageUrl": "/static/uploads/product.png",
            "status": "available",
        },
    )
    assert product_response.status_code == 201
    assert product_response.json()["imageUrl"] == "/static/uploads/product.png"
    catalog_response = client.get("/projects/catalog", headers=customer_headers)
    assert catalog_response.status_code == 200
    catalog_item = next(
        item
        for item in catalog_response.json()
        if item["id"] == product_response.json()["id"]
    )
    assert catalog_item["imageUrl"] == "/static/uploads/product.png"

    batch_response = client.post(
        "/batches",
        headers=farmer_headers,
        json={
            "batchId": "IMG-BATCH-001",
            "type": "Mature Bamboo",
            "quantityAvailable": 20,
            "quantityUnit": "kg",
            "location": "Coorg",
            "imageUrl": "/static/uploads/batch.png",
        },
    )
    assert batch_response.status_code == 201
    assert batch_response.json()["imageUrl"] == "/static/uploads/batch.png"

    request_response = client.post(
        "/custom-order-requests",
        headers=customer_headers,
        json={
            "targetArtisanId": artisan["id"],
            "title": "Custom bamboo screen",
            "description": "Room divider with a woven pattern.",
            "quantity": 1,
            "imageUrl": "/static/uploads/request.png",
        },
    )
    assert request_response.status_code == 201
    assert request_response.json()["customerId"] == customer["id"]
    assert request_response.json()["imageUrl"] == "/static/uploads/request.png"


def test_customer_custom_request_is_visible_only_to_target_artisan() -> None:
    customer, customer_headers = signup("customer")
    target_artisan, target_headers = signup("artisan")
    other_artisan, other_headers = signup("artisan")

    create_response = client.post(
        "/custom-order-requests",
        headers=customer_headers,
        json={
            "targetArtisanId": target_artisan["id"],
            "title": "Custom bamboo crib",
            "description": "Need a rounded edge crib for a nursery.",
            "quantity": 1,
            "budget": 8000,
            "deadline": "2026-08-01",
        },
    )

    assert create_response.status_code == 201
    request = create_response.json()
    assert request["customerId"] == customer["id"]
    assert request["targetArtisanId"] == target_artisan["id"]
    assert request["status"] == "open"
    assert request["deadline"].startswith("2026-08-01")

    target_active = client.get("/custom-order-requests/active", headers=target_headers)
    other_active = client.get("/custom-order-requests/active", headers=other_headers)
    assert target_active.status_code == 200
    assert other_active.status_code == 200
    assert len(target_active.json()) == 1
    assert other_active.json() == []
    target_notifications = client.get("/notifications", headers=target_headers)
    other_notifications = client.get("/notifications", headers=other_headers)
    assert target_notifications.status_code == 200
    assert other_notifications.status_code == 200
    assert target_notifications.json()[0]["entityType"] == "custom_order_request"
    assert target_notifications.json()[0]["entityId"] == request["id"]
    assert (
        target_notifications.json()[0]["navigationTarget"]
        == f"/custom-requests/{request['id']}"
    )
    assert other_notifications.json() == []

    forbidden = client.post(
        f"/custom-order-requests/{request['id']}/accept",
        headers=other_headers,
    )
    assert forbidden.status_code == 404


def test_accepting_custom_request_creates_custom_product_order() -> None:
    customer, customer_headers = signup("customer")
    artisan, artisan_headers = signup("artisan")
    create_response = client.post(
        "/custom-order-requests",
        headers=customer_headers,
        json={
            "targetArtisanId": artisan["id"],
            "title": "Custom bamboo desk",
            "description": "Two drawer writing desk.",
            "quantity": 1,
        },
    )
    assert create_response.status_code == 201

    accept_response = client.post(
        f"/custom-order-requests/{create_response.json()['id']}/accept",
        headers=artisan_headers,
    )
    assert accept_response.status_code == 200
    accepted = accept_response.json()
    assert accepted["status"] == "accepted"
    assert accepted["orderId"] is not None

    customer_orders = client.get("/orders", headers=customer_headers)
    artisan_orders = client.get("/orders", headers=artisan_headers)
    assert customer_orders.status_code == 200
    assert artisan_orders.status_code == 200
    assert len(customer_orders.json()) == 1
    assert len(artisan_orders.json()) == 1
    assert customer_orders.json()[0]["orderType"] == "custom_product_order"
    customer_notifications = client.get("/notifications", headers=customer_headers)
    assert customer_notifications.status_code == 200
    assert customer_notifications.json()[0]["type"] == "request_accepted"
    assert customer_notifications.json()[0]["entityType"] == "order"
    assert customer_notifications.json()[0]["entityId"] == accepted["orderId"]


def test_rejecting_custom_request_does_not_create_order() -> None:
    _, customer_headers = signup("customer")
    _, artisan_headers = signup("artisan")
    artisan_me = client.get("/auth/me", headers=artisan_headers).json()
    create_response = client.post(
        "/custom-order-requests",
        headers=customer_headers,
        json={
            "targetArtisanId": artisan_me["id"],
            "title": "Custom bamboo shelf",
            "description": "Wall mounted shelf.",
            "quantity": 2,
        },
    )
    assert create_response.status_code == 201

    reject_response = client.post(
        f"/custom-order-requests/{create_response.json()['id']}/reject",
        headers=artisan_headers,
    )
    assert reject_response.status_code == 200
    assert reject_response.json()["status"] == "rejected"
    assert reject_response.json()["orderId"] is None

    orders = client.get("/orders", headers=customer_headers)
    assert orders.status_code == 200
    assert orders.json() == []
    customer_notifications = client.get("/notifications", headers=customer_headers)
    assert customer_notifications.status_code == 200
    assert customer_notifications.json()[0]["type"] == "request_rejected"
    assert customer_notifications.json()[0]["entityType"] == "custom_order_request"


def test_broadcast_custom_request_is_visible_to_all_artisans() -> None:
    customer, customer_headers = signup("customer")
    _, first_artisan_headers = signup("artisan")
    _, second_artisan_headers = signup("artisan")

    create_response = client.post(
        "/custom-order-requests",
        headers=customer_headers,
        json={
            "targetType": "broadcast",
            "title": "Custom bamboo lamp",
            "description": "Need a pendant lamp with woven shade.",
            "quantity": 3,
        },
    )

    assert create_response.status_code == 201
    request = create_response.json()
    assert request["customerId"] == customer["id"]
    assert request["targetType"] == "broadcast"
    assert request["targetArtisanId"] is None
    assert request["status"] == "open"

    first_active = client.get(
        "/custom-order-requests/active", headers=first_artisan_headers
    )
    second_active = client.get(
        "/custom-order-requests/active", headers=second_artisan_headers
    )
    assert first_active.status_code == 200
    assert second_active.status_code == 200
    assert [item["id"] for item in first_active.json()] == [request["id"]]
    assert [item["id"] for item in second_active.json()] == [request["id"]]
    first_notifications = client.get(
        "/notifications", headers=first_artisan_headers
    )
    second_notifications = client.get(
        "/notifications", headers=second_artisan_headers
    )
    assert first_notifications.status_code == 200
    assert second_notifications.status_code == 200
    assert first_notifications.json()[0]["entityId"] == request["id"]
    assert second_notifications.json()[0]["entityId"] == request["id"]


def test_first_artisan_to_accept_broadcast_custom_request_wins() -> None:
    _, customer_headers = signup("customer")
    first_artisan, first_artisan_headers = signup("artisan")
    _, second_artisan_headers = signup("artisan")
    create_response = client.post(
        "/custom-order-requests",
        headers=customer_headers,
        json={
            "targetType": "broadcast",
            "title": "Custom bamboo table",
            "description": "Round dining table for four.",
            "quantity": 1,
        },
    )
    assert create_response.status_code == 201

    accept_response = client.post(
        f"/custom-order-requests/{create_response.json()['id']}/accept",
        headers=first_artisan_headers,
    )
    assert accept_response.status_code == 200
    accepted = accept_response.json()
    assert accepted["status"] == "accepted"
    assert accepted["acceptedByArtisanId"] == first_artisan["id"]
    assert accepted["orderId"] is not None

    second_accept = client.post(
        f"/custom-order-requests/{create_response.json()['id']}/accept",
        headers=second_artisan_headers,
    )
    assert second_accept.status_code == 409

    first_orders = client.get("/orders", headers=first_artisan_headers)
    second_orders = client.get("/orders", headers=second_artisan_headers)
    assert first_orders.status_code == 200
    assert second_orders.status_code == 200
    assert len(first_orders.json()) == 1
    assert first_orders.json()[0]["artisanId"] == first_artisan["id"]
    assert second_orders.json() == []


def test_broadcast_rejection_by_one_artisan_does_not_close_for_others() -> None:
    _, customer_headers = signup("customer")
    _, first_artisan_headers = signup("artisan")
    _, second_artisan_headers = signup("artisan")
    create_response = client.post(
        "/custom-order-requests",
        headers=customer_headers,
        json={
            "targetType": "broadcast",
            "title": "Custom bamboo tray",
            "description": "Set of nested serving trays.",
            "quantity": 4,
        },
    )
    assert create_response.status_code == 201
    request_id = create_response.json()["id"]

    reject_response = client.post(
        f"/custom-order-requests/{request_id}/reject",
        headers=first_artisan_headers,
    )
    assert reject_response.status_code == 200
    assert reject_response.json()["status"] == "open"
    assert reject_response.json()["rejectedByCurrentUser"] is True
    assert reject_response.json()["orderId"] is None

    first_active = client.get(
        "/custom-order-requests/active", headers=first_artisan_headers
    )
    first_history = client.get(
        "/custom-order-requests/history", headers=first_artisan_headers
    )
    second_active = client.get(
        "/custom-order-requests/active", headers=second_artisan_headers
    )
    assert first_active.status_code == 200
    assert first_history.status_code == 200
    assert second_active.status_code == 200
    assert request_id not in {item["id"] for item in first_active.json()}
    assert request_id in {item["id"] for item in first_history.json()}
    assert request_id in {item["id"] for item in second_active.json()}

    orders = client.get("/orders", headers=customer_headers)
    assert orders.status_code == 200
    assert orders.json() == []


def test_artisan_can_place_direct_material_order_for_farmer_batch() -> None:
    artisan, artisan_headers = signup("artisan")
    farmer, farmer_headers = signup("farmer")
    batch = create_batch(farmer_headers)

    order_response = client.post(
        "/orders/material",
        headers=artisan_headers,
        json={
            "batchId": batch["id"],
            "quantity": 5,
            "quantityUnit": "kg",
            "fulfillmentType": "delivery",
        },
    )

    assert order_response.status_code == 201
    order = order_response.json()
    assert order["artisanId"] == artisan["id"]
    assert order["farmerId"] == farmer["id"]
    assert order["batchId"] == batch["id"]
    assert order["orderType"] == "material_order"
    assert order["fulfillmentType"] == "delivery"

    artisan_orders = client.get("/orders", headers=artisan_headers)
    farmer_orders = client.get("/orders", headers=farmer_headers)
    assert artisan_orders.status_code == 200
    assert farmer_orders.status_code == 200
    assert len(artisan_orders.json()) == 1
    assert len(farmer_orders.json()) == 1
    farmer_order = farmer_orders.json()[0]
    assert farmer_order["artisan"]["id"] == artisan["id"]
    assert farmer_order["artisan"]["name"] == artisan["name"]
    assert farmer_order["quantity"] == 5
    assert farmer_order["quantityUnit"] == "kg"
    assert farmer_order["fulfillmentType"] == "delivery"
    assert farmer_order["createdAt"] is not None
    farmer_notifications = client.get("/notifications", headers=farmer_headers)
    assert farmer_notifications.status_code == 200
    assert farmer_notifications.json()[0]["type"] == "request_created"
    assert farmer_notifications.json()[0]["entityType"] == "order"
    assert farmer_notifications.json()[0]["entityId"] == order["id"]
    assert farmer_notifications.json()[0]["navigationTarget"] == f"/orders/{order['id']}"


def test_notification_endpoints_are_user_scoped_and_support_read_state() -> None:
    _, customer_headers = signup("customer")
    _, artisan_headers = signup("artisan")
    project = create_project(artisan_headers)
    order_response = client.post(
        "/orders/product",
        headers=customer_headers,
        json={
            "productId": project["id"],
            "quantity": 1,
            "quantityUnit": "item",
            "fulfillmentType": "pickup",
        },
    )
    assert order_response.status_code == 201

    customer_notifications = client.get("/notifications", headers=customer_headers)
    artisan_notifications = client.get("/notifications", headers=artisan_headers)
    assert customer_notifications.status_code == 200
    assert artisan_notifications.status_code == 200
    assert customer_notifications.json() == []
    assert len(artisan_notifications.json()) == 1

    unread = client.get("/notifications/unread-count", headers=artisan_headers)
    assert unread.status_code == 200
    assert unread.json()["count"] == 1

    notification_id = artisan_notifications.json()[0]["id"]
    forbidden_read = client.post(
        f"/notifications/{notification_id}/read",
        headers=customer_headers,
    )
    assert forbidden_read.status_code == 404

    read_response = client.post(
        f"/notifications/{notification_id}/read",
        headers=artisan_headers,
    )
    assert read_response.status_code == 200
    assert read_response.json()["readAt"] is not None

    unread_after_read = client.get(
        "/notifications/unread-count", headers=artisan_headers
    )
    assert unread_after_read.status_code == 200
    assert unread_after_read.json()["count"] == 0


def test_product_order_receiver_generates_otp_and_seller_verifies() -> None:
    _, customer_headers = signup("customer")
    _, artisan_headers = signup("artisan")
    order = create_product_order_for_test(customer_headers, artisan_headers)

    seller_generate = client.post(
        f"/orders/{order['id']}/generate-handover-otp",
        headers=artisan_headers,
    )
    assert seller_generate.status_code == 403

    generate = client.post(
        f"/orders/{order['id']}/generate-handover-otp",
        headers=customer_headers,
    )
    assert generate.status_code == 200
    otp_payload = generate.json()
    assert len(otp_payload["otp"]) == 6
    assert otp_payload["otp"].isdigit()
    assert otp_payload["expiresAt"] is not None

    wrong = client.post(
        f"/orders/{order['id']}/verify-handover-otp",
        headers=artisan_headers,
        json={"otp": "000000"},
    )
    assert wrong.status_code == 400

    verify = client.post(
        f"/orders/{order['id']}/verify-handover-otp",
        headers=artisan_headers,
        json={"otp": otp_payload["otp"]},
    )
    assert verify.status_code == 200
    verified = verify.json()
    assert verified["fulfillmentStatus"] == "received"
    assert verified["handoverVerifiedAt"] is not None
    assert verified["receiverConfirmedAt"] is not None
    assert verified["completedAt"] is not None
    assert verified["status"] == "completed"


def test_material_order_artisan_receives_otp_and_farmer_verifies() -> None:
    _, artisan_headers = signup("artisan")
    _, farmer_headers = signup("farmer")
    order = create_material_order_for_test(artisan_headers, farmer_headers)

    wrong_receiver = client.post(
        f"/orders/{order['id']}/generate-handover-otp",
        headers=farmer_headers,
    )
    assert wrong_receiver.status_code == 403

    generate = client.post(
        f"/orders/{order['id']}/generate-handover-otp",
        headers=artisan_headers,
    )
    assert generate.status_code == 200

    wrong_seller = client.post(
        f"/orders/{order['id']}/verify-handover-otp",
        headers=artisan_headers,
        json={"otp": generate.json()["otp"]},
    )
    assert wrong_seller.status_code == 403

    verify = client.post(
        f"/orders/{order['id']}/verify-handover-otp",
        headers=farmer_headers,
        json={"otp": generate.json()["otp"]},
    )
    assert verify.status_code == 200
    verified = verify.json()
    assert verified["fulfillmentStatus"] == "received"
    assert verified["handoverVerifiedAt"] is not None
    assert verified["receiverConfirmedAt"] is not None
    assert verified["completedAt"] is not None
    assert verified["status"] == "completed"


def test_expired_handover_otp_fails() -> None:
    _, customer_headers = signup("customer")
    _, artisan_headers = signup("artisan")
    order = create_product_order_for_test(customer_headers, artisan_headers)

    generate = client.post(
        f"/orders/{order['id']}/generate-handover-otp",
        headers=customer_headers,
    )
    assert generate.status_code == 200
    with SessionLocal() as db:
        stored_order = db.get(Order, order["id"])
        assert stored_order is not None
        stored_order.handover_otp_expires_at = datetime.now(timezone.utc) - timedelta(
            minutes=1
        )
        db.commit()

    verify = client.post(
        f"/orders/{order['id']}/verify-handover-otp",
        headers=artisan_headers,
        json={"otp": generate.json()["otp"]},
    )
    assert verify.status_code == 400


def test_receiver_can_report_dispute_after_handover() -> None:
    _, customer_headers = signup("customer")
    _, artisan_headers = signup("artisan")
    order = create_product_order_for_test(customer_headers, artisan_headers)

    seller_dispute = client.post(
        f"/orders/{order['id']}/report-dispute",
        headers=artisan_headers,
    )
    assert seller_dispute.status_code == 403

    dispute = client.post(
        f"/orders/{order['id']}/report-dispute",
        headers=customer_headers,
    )
    assert dispute.status_code == 200
    assert dispute.json()["fulfillmentStatus"] == "disputed"
    assert dispute.json()["status"] != "completed"


def test_farmer_can_create_available_and_upcoming_batches_visible_to_artisan() -> None:
    _, artisan_headers = signup("artisan")
    _, farmer_headers = signup("farmer")

    available = client.post(
        "/batches",
        headers=farmer_headers,
        json={
            "batchId": "AVAILABLE-001",
            "type": "Mature Bamboo",
            "quantityAvailable": 30,
            "quantityUnit": "kg",
            "location": "Coorg",
            "availableNow": True,
            "status": "available",
            "price": 120,
        },
    )
    assert available.status_code == 201
    assert available.json()["quantityAvailable"] == 30
    assert available.json()["status"] == "available"

    upcoming = client.post(
        "/batches",
        headers=farmer_headers,
        json={
            "batchId": "UPCOMING-002",
            "type": "Young Bamboo",
            "quantityAvailable": 0,
            "quantityUnit": "kg",
            "location": "Wayanad",
            "availableNow": False,
            "status": "upcoming",
            "expectedHarvestDate": "2026-07-15",
        },
    )
    assert upcoming.status_code == 201
    assert upcoming.json()["status"] == "upcoming"

    catalog = client.get("/batches/catalog", headers=artisan_headers)
    assert catalog.status_code == 200
    statuses = {batch["status"] for batch in catalog.json()}
    assert {"available", "upcoming"}.issubset(statuses)


def test_upcoming_batch_requires_future_date() -> None:
    _, farmer_headers = signup("farmer")

    response = client.post(
        "/batches",
        headers=farmer_headers,
        json={
            "batchId": "BAD-UPCOMING",
            "type": "Young Bamboo",
            "quantityAvailable": 0,
            "location": "Wayanad",
            "availableNow": False,
            "status": "upcoming",
        },
    )

    assert response.status_code == 422


def test_direct_material_order_rejects_quantity_above_available_stock() -> None:
    _, artisan_headers = signup("artisan")
    _, farmer_headers = signup("farmer")
    batch = create_batch(farmer_headers)

    response = client.post(
        "/orders/material",
        headers=artisan_headers,
        json={
            "batchId": batch["id"],
            "quantity": batch["quantity"] + 1,
            "quantityUnit": "kg",
            "fulfillmentType": "pickup",
        },
    )

    assert response.status_code == 400


def test_direct_material_order_allows_upcoming_batch_preorder() -> None:
    _, artisan_headers = signup("artisan")
    _, farmer_headers = signup("farmer")
    future_harvest_date = (
        datetime.now(timezone.utc) + timedelta(days=30)
    ).isoformat().replace("+00:00", "Z")
    batch_response = client.post(
        "/batches",
        headers=farmer_headers,
        json={
            "batchId": "UPCOMING-001",
            "type": "Green Bamboo",
            "quantity": 0,
            "location": "Wayanad",
            "expectedHarvestDate": future_harvest_date,
        },
    )
    assert batch_response.status_code == 201

    response = client.post(
        "/orders/material",
        headers=artisan_headers,
        json={
            "batchId": batch_response.json()["id"],
            "quantity": 20,
            "quantityUnit": "kg",
            "fulfillmentType": "delivery",
        },
    )

    assert response.status_code == 201


def test_rejected_request_leaves_active_workflow_without_order() -> None:
    customer, customer_headers = signup("customer")
    artisan, artisan_headers = signup("artisan")
    project = create_project(artisan_headers)

    request_response = client.post(
        "/order-requests",
        headers=customer_headers,
        json={
            "requestType": "customer_to_artisan",
            "receiverId": artisan["id"],
            "productId": project["id"],
            "quantity": 1,
            "quantityUnit": "item",
        },
    )
    assert request_response.status_code == 201

    reject_response = client.post(
        f"/order-requests/{request_response.json()['id']}/reject",
        headers=artisan_headers,
    )
    assert reject_response.status_code == 200
    assert reject_response.json()["status"] == "rejected"

    active_response = client.get("/order-requests/active", headers=artisan_headers)
    assert active_response.status_code == 200
    assert active_response.json() == []

    orders_response = client.get("/orders", headers=customer_headers)
    assert orders_response.status_code == 200
    assert orders_response.json() == []


def test_artisan_material_request_updates_farmer_order_visibility() -> None:
    customer, customer_headers = signup("customer")
    artisan, artisan_headers = signup("artisan")
    farmer, farmer_headers = signup("farmer")
    project = create_project(artisan_headers)
    batch = create_batch(farmer_headers)

    customer_request = client.post(
        "/order-requests",
        headers=customer_headers,
        json={
            "requestType": "customer_to_artisan",
            "receiverId": artisan["id"],
            "productId": project["id"],
            "quantity": 3,
            "quantityUnit": "item",
        },
    )
    assert customer_request.status_code == 201
    accepted = client.post(
        f"/order-requests/{customer_request.json()['id']}/accept",
        headers=artisan_headers,
    )
    assert accepted.status_code == 200
    order_id = accepted.json()["orderId"]

    material_request = client.post(
        "/order-requests",
        headers=artisan_headers,
        json={
            "requestType": "artisan_to_farmer",
            "receiverId": farmer["id"],
            "orderId": order_id,
            "batchId": batch["id"],
            "quantity": 10,
            "quantityUnit": "kg",
            "notes": "Need treated culms.",
        },
    )
    assert material_request.status_code == 201

    accept_material = client.post(
        f"/order-requests/{material_request.json()['id']}/accept",
        headers=farmer_headers,
    )
    assert accept_material.status_code == 200

    farmer_orders = client.get("/orders", headers=farmer_headers)
    assert farmer_orders.status_code == 200
    assert len(farmer_orders.json()) == 1
    assert farmer_orders.json()[0]["farmerId"] == farmer["id"]


def test_order_status_transitions_are_validated() -> None:
    customer, customer_headers = signup("customer")
    artisan, artisan_headers = signup("artisan")
    project = create_project(artisan_headers)

    request_response = client.post(
        "/order-requests",
        headers=customer_headers,
        json={
            "requestType": "customer_to_artisan",
            "receiverId": artisan["id"],
            "productId": project["id"],
            "quantity": 1,
        },
    )
    assert request_response.status_code == 201
    accepted = client.post(
        f"/order-requests/{request_response.json()['id']}/accept",
        headers=artisan_headers,
    )
    order_id = accepted.json()["orderId"]

    invalid = client.patch(
        f"/orders/{order_id}/status",
        headers=customer_headers,
        json={"status": "rejected"},
    )
    assert invalid.status_code == 403

    progress = client.patch(
        f"/orders/{order_id}/status",
        headers=artisan_headers,
        json={"status": "in_progress"},
    )
    assert progress.status_code == 200
    assert progress.json()["status"] == "in_progress"

    manual_complete = client.patch(
        f"/orders/{order_id}/status",
        headers=artisan_headers,
        json={"status": "completed"},
    )
    assert manual_complete.status_code == 409

    customer_notifications = client.get("/notifications", headers=customer_headers)
    assert customer_notifications.status_code == 200
    assert customer_notifications.json()[0]["type"] == "order_status_changed"
    assert customer_notifications.json()[0]["entityType"] == "order"
    assert customer_notifications.json()[0]["entityId"] == order_id

def test_only_order_seller_can_start_order() -> None:
    _, customer_headers = signup("customer")
    _, artisan_headers = signup("artisan")
    order = create_product_order_for_test(customer_headers, artisan_headers)

    customer_start = client.patch(
        f"/orders/{order['id']}/status",
        headers=customer_headers,
        json={"status": "in_progress"},
    )
    assert customer_start.status_code == 403

    artisan_start = client.patch(
        f"/orders/{order['id']}/status",
        headers=artisan_headers,
        json={"status": "in_progress"},
    )
    assert artisan_start.status_code == 200
    assert artisan_start.json()["status"] == "in_progress"
