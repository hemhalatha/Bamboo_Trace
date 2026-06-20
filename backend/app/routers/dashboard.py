from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models import (
    Batch,
    BatchStatus,
    CustomOrderRequest,
    CustomRequestStatus,
    CustomRequestTargetType,
    Notification,
    Order,
    OrderStatus,
    OrderType,
    Project,
    User,
    UserRole,
)

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


def _count(db: Session, statement) -> int:
    return int(db.scalar(statement) or 0)


def _active_order_filter():
    return (
        ~Order.status.in_([OrderStatus.completed, OrderStatus.rejected]),
        ~Order.fulfillment_status.in_(["received", "disputed"]),
    )


def _rejected_artisan_ids(request: CustomOrderRequest) -> set[str]:
    raw_ids = request.rejected_artisan_ids or ""
    return {artisan_id for artisan_id in raw_ids.split(",") if artisan_id}


def _artisan_custom_request_counts(db: Session, user: User) -> tuple[int, int]:
    visible_requests = list(
        db.scalars(
            select(CustomOrderRequest).where(
                (
                    CustomOrderRequest.target_artisan_id == user.id
                )
                | (
                    CustomOrderRequest.target_type
                    == CustomRequestTargetType.broadcast
                )
            )
        )
    )
    active_requests = [
        request
        for request in visible_requests
        if request.status == CustomRequestStatus.open
        and (
            request.target_type != CustomRequestTargetType.broadcast
            or user.id not in _rejected_artisan_ids(request)
        )
    ]
    return len(visible_requests), len(active_requests)


@router.get("/stats")
def dashboard_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, int | str]:
    unread_notifications = _count(
        db,
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == current_user.id, Notification.read_at.is_(None)),
    )

    if current_user.role == UserRole.customer:
        total_orders = _count(
            db,
            select(func.count())
            .select_from(Order)
            .where(Order.customer_id == current_user.id),
        )
        active_orders = _count(
            db,
            select(func.count())
            .select_from(Order)
            .where(Order.customer_id == current_user.id, *_active_order_filter()),
        )
        custom_requests = _count(
            db,
            select(func.count())
            .select_from(CustomOrderRequest)
            .where(CustomOrderRequest.customer_id == current_user.id),
        )
        active_custom_requests = _count(
            db,
            select(func.count())
            .select_from(CustomOrderRequest)
            .where(
                CustomOrderRequest.customer_id == current_user.id,
                CustomOrderRequest.status == CustomRequestStatus.open,
            ),
        )
        available_products = _count(
            db,
            select(func.count())
            .select_from(Project)
            .where(Project.is_hidden.is_(False), Project.quantity > 0),
        )
        return {
            "role": current_user.role.value,
            "totalOrders": total_orders,
            "activeOrders": active_orders,
            "customRequests": custom_requests,
            "activeCustomRequests": active_custom_requests,
            "availableProducts": available_products,
            "unreadNotifications": unread_notifications,
        }

    if current_user.role == UserRole.artisan:
        product_orders_received = _count(
            db,
            select(func.count())
            .select_from(Order)
            .where(
                Order.artisan_id == current_user.id,
                Order.order_type == OrderType.product_order,
            ),
        )
        custom_product_orders = _count(
            db,
            select(func.count())
            .select_from(Order)
            .where(
                Order.artisan_id == current_user.id,
                Order.order_type == OrderType.custom_product_order,
            ),
        )
        material_orders_placed = _count(
            db,
            select(func.count())
            .select_from(Order)
            .where(
                Order.artisan_id == current_user.id,
                Order.order_type == OrderType.material_order,
            ),
        )
        products_listed = _count(
            db,
            select(func.count())
            .select_from(Project)
            .where(Project.owner_id == current_user.id),
        )
        custom_requests, active_custom_requests = _artisan_custom_request_counts(
            db, current_user
        )
        return {
            "role": current_user.role.value,
            "productOrdersReceived": product_orders_received,
            "customProductOrders": custom_product_orders,
            "materialOrdersPlaced": material_orders_placed,
            "productsListed": products_listed,
            "customRequests": custom_requests,
            "activeCustomRequests": active_custom_requests,
            "unreadNotifications": unread_notifications,
        }

    material_orders_received = _count(
        db,
        select(func.count())
        .select_from(Order)
        .where(
            Order.farmer_id == current_user.id,
            Order.order_type == OrderType.material_order,
        ),
    )
    active_material_orders = _count(
        db,
        select(func.count())
        .select_from(Order)
        .where(
            Order.farmer_id == current_user.id,
            Order.order_type == OrderType.material_order,
            *_active_order_filter(),
        ),
    )
    batches_listed = _count(
        db,
        select(func.count()).select_from(Batch).where(Batch.owner_id == current_user.id),
    )
    active_batches = _count(
        db,
        select(func.count())
        .select_from(Batch)
        .where(
            Batch.owner_id == current_user.id,
            Batch.status.in_([BatchStatus.available, BatchStatus.upcoming]),
        ),
    )
    upcoming_batches = _count(
        db,
        select(func.count())
        .select_from(Batch)
        .where(
            Batch.owner_id == current_user.id,
            Batch.status == BatchStatus.upcoming,
        ),
    )
    return {
        "role": current_user.role.value,
        "materialOrdersReceived": material_orders_received,
        "activeMaterialOrders": active_material_orders,
        "batchesListed": batches_listed,
        "activeBatches": active_batches,
        "upcomingBatches": upcoming_batches,
        "unreadNotifications": unread_notifications,
    }
