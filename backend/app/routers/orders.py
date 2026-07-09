import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.deps import get_current_user, require_roles, require_roles_with_complete_profile
from app.models import (
    Batch,
    BatchStatus,
    NotificationType,
    Order,
    OrderStatus,
    OrderType,
    Project,
    User,
    UserRole,
)
from app.routers.order_requests import create_notification
from app.schemas import (
    HandoverOtpPublic,
    HandoverOtpVerify,
    MaterialOrderCreate,
    OrderCreate,
    OrderPublic,
    OrderStatusUpdate,
    ProductOrderCreate,
)

router = APIRouter(prefix="/orders", tags=["orders"])

OTP_EXPIRY_MINUTES = 10
FULFILLMENT_PENDING = "pending_handover"
FULFILLMENT_OTP_GENERATED = "otp_generated"
FULFILLMENT_HANDOVER_VERIFIED = "handover_verified"
FULFILLMENT_RECEIVED = "received"
FULFILLMENT_DISPUTED = "disputed"


@router.get("", response_model=list[OrderPublic])
def list_orders(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Order]:
    if current_user.role == UserRole.customer:
        visibility_filter = Order.customer_id == current_user.id
    elif current_user.role == UserRole.artisan:
        visibility_filter = Order.artisan_id == current_user.id
    else:
        visibility_filter = Order.farmer_id == current_user.id

    orders = list(
        db.scalars(
            select(Order)
            .where(visibility_filter)
            .order_by(Order.created_at.desc())
        )
    )
    return [_load_order_details(db, order) for order in orders]


@router.get("/{order_id}", response_model=OrderPublic)
def get_order(
    order_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Order:
    return _load_order_details(db, _get_visible_order(db, order_id, current_user))


def _load_order_details(db: Session, order: Order) -> Order:
    order.customer = db.get(User, order.customer_id) if order.customer_id else None
    order.artisan = db.get(User, order.artisan_id) if order.artisan_id else None
    order.farmer = db.get(User, order.farmer_id) if order.farmer_id else None
    order.product = db.get(Project, order.product_id) if order.product_id else None
    order.batch = db.get(Batch, order.batch_id) if order.batch_id else None
    return order


def _mark_order_product_sold(db: Session, order: Order) -> None:
    if order.order_type != OrderType.product_order or not order.product_id:
        return
    product = db.get(Project, order.product_id)
    if product is not None:
        product.status = "sold"


@router.post("", response_model=OrderPublic, status_code=status.HTTP_201_CREATED)
def create_order(
    payload: OrderCreate,
    current_user: User = Depends(require_roles_with_complete_profile(UserRole.customer)),
    db: Session = Depends(get_db),
) -> Order:
    order = Order(
        owner_id=current_user.id,
        customer_id=current_user.id,
        **payload.model_dump(by_alias=False),
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return _load_order_details(db, order)


@router.post("/product", response_model=OrderPublic, status_code=status.HTTP_201_CREATED)
def create_product_order(
    payload: ProductOrderCreate,
    current_user: User = Depends(require_roles_with_complete_profile(UserRole.customer)),
    db: Session = Depends(get_db),
) -> Order:
    product = db.get(Project, payload.product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )
    if product.is_hidden:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Product is not available for sale",
        )
    product_status = (product.status or "available").lower()
    if product_status != "available":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Product is not available for sale",
        )
    if product.quantity <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Product is out of stock",
        )
    if payload.quantity > product.quantity:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Requested quantity exceeds available stock",
        )

    order = Order(
        owner_id=current_user.id,
        customer_id=current_user.id,
        artisan_id=product.owner_id,
        product_id=product.id,
        product_name=product.product_name,
        product_type=product.product_type,
        order_type=OrderType.product_order,
        quantity=payload.quantity,
        quantity_unit=payload.quantity_unit,
        fulfillment_type=payload.fulfillment_type,
        status=OrderStatus.accepted,
        accepted_at=datetime.now(timezone.utc),
        price=product.price or 0,
    )
    product.quantity -= payload.quantity
    product.status = "sold" if product.quantity <= 0 else "ordered"
    db.add(order)
    db.flush()
    create_notification(
        db,
        user_id=product.owner_id,
        notification_type=NotificationType.request_created,
        title="New product order",
        body=f"{current_user.name} placed an order for {product.product_name}",
        entity_type="order",
        entity_id=order.id,
    )
    db.commit()
    db.refresh(order)
    return _load_order_details(db, order)


@router.post("/material", response_model=OrderPublic, status_code=status.HTTP_201_CREATED)
def create_material_order(
    payload: MaterialOrderCreate,
    current_user: User = Depends(require_roles_with_complete_profile(UserRole.artisan)),
    db: Session = Depends(get_db),
) -> Order:
    batch = db.get(Batch, payload.batch_id)
    if batch is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Batch not found",
        )
    if batch.status == BatchStatus.hidden:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Batch is not available for sale",
        )
    if batch.status == BatchStatus.sold_out:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Batch is sold out",
        )
    available_quantity = batch.quantity_available
    if available_quantity > 0 and payload.quantity > available_quantity:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Requested quantity exceeds available stock",
        )
    if available_quantity <= 0 and batch.expected_harvest_date is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Batch is out of stock",
        )

    order = Order(
        owner_id=current_user.id,
        artisan_id=current_user.id,
        farmer_id=batch.owner_id,
        batch_id=batch.id,
        product_name=batch.type,
        product_type="material",
        order_type=OrderType.material_order,
        quantity=payload.quantity,
        quantity_unit=payload.quantity_unit,
        fulfillment_type=payload.fulfillment_type,
        status=OrderStatus.accepted,
        accepted_at=datetime.now(timezone.utc),
        price=batch.price or 0,
    )
    if batch.quantity_available > 0:
        batch.quantity_available -= payload.quantity
        batch.quantity = batch.quantity_available
    if batch.quantity_available == 0 and batch.status == BatchStatus.available:
        batch.status = BatchStatus.sold_out
        batch.available_now = False
    db.add(order)
    db.flush()
    create_notification(
        db,
        user_id=batch.owner_id,
        notification_type=NotificationType.request_created,
        title="New material order",
        body=f"{current_user.name} placed an order for {batch.type}",
        entity_type="order",
        entity_id=order.id,
    )
    db.commit()
    db.refresh(order)
    return _load_order_details(db, order)


VALID_STATUS_TRANSITIONS: dict[OrderStatus, set[OrderStatus]] = {
    OrderStatus.pending: {OrderStatus.accepted, OrderStatus.rejected},
    OrderStatus.accepted: {OrderStatus.in_progress},
    OrderStatus.in_progress: set(),
    OrderStatus.rejected: set(),
    OrderStatus.completed: set(),
}


def _can_access_order(order: Order, user: User) -> bool:
    return user.id in {order.customer_id, order.artisan_id, order.farmer_id}


def _order_receiver_id(order: Order) -> str | None:
    if order.order_type == OrderType.material_order:
        return order.artisan_id
    return order.customer_id


def _order_seller_id(order: Order) -> str | None:
    if order.order_type == OrderType.material_order:
        return order.farmer_id
    if order.order_type in {
        OrderType.product_order,
        OrderType.custom_product_order,
        OrderType.custom_request,
    }:
        return order.artisan_id
    return None


def _require_order_receiver(order: Order, user: User) -> None:
    if _order_receiver_id(order) != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the order receiver can perform this action",
        )


def _require_order_seller(order: Order, user: User) -> None:
    if _order_seller_id(order) != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the order seller can perform this action",
        )


def _get_visible_order(db: Session, order_id: str, user: User) -> Order:
    order = db.get(Order, order_id)
    if order is None or not _can_access_order(order, user):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )
    return order


def _hash_otp(order_id: str, otp: str) -> str:
    value = f"{order_id}:{otp}:{settings.jwt_secret_key}".encode()
    return hashlib.sha256(value).hexdigest()


def _generate_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _utc_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


@router.patch("/{order_id}/status", response_model=OrderPublic)
def update_order_status(
    order_id: str,
    payload: OrderStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Order:
    order = db.get(Order, order_id)
    if order is None or not _can_access_order(order, current_user):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Order not found",
        )

    _require_order_seller(order, current_user)

    allowed_statuses = VALID_STATUS_TRANSITIONS.get(order.status, set())
    if payload.status not in allowed_statuses:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot move order from {order.status.value} to {payload.status.value}",
        )

    order.status = payload.status
    if payload.status == OrderStatus.accepted:
        order.accepted_at = datetime.now(timezone.utc)
    elif payload.status == OrderStatus.rejected:
        order.rejected_at = datetime.now(timezone.utc)
    elif payload.status == OrderStatus.completed:
        order.completed_at = datetime.now(timezone.utc)
        _mark_order_product_sold(db, order)

    participant_ids = {
        user_id
        for user_id in [order.customer_id, order.artisan_id, order.farmer_id]
        if user_id and user_id != current_user.id
    }
    for user_id in participant_ids:
        create_notification(
            db,
            user_id=user_id,
            notification_type=NotificationType.order_status_changed,
            title="Order status changed",
            body=f"Order {order.id} is now {payload.status.value}",
            entity_type="order",
            entity_id=order.id,
        )

    db.commit()
    db.refresh(order)
    return _load_order_details(db, order)


@router.post("/{order_id}/generate-handover-otp", response_model=HandoverOtpPublic)
def generate_handover_otp(
    order_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict[str, datetime | str]:
    order = _get_visible_order(db, order_id, current_user)
    _require_order_receiver(order, current_user)
    if order.status in {OrderStatus.rejected, OrderStatus.completed}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot generate OTP for a closed order",
        )
    if _order_seller_id(order) is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Order does not have a seller assigned",
        )

    otp = _generate_otp()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES)
    order.handover_otp_hash = _hash_otp(order.id, otp)
    order.handover_otp_expires_at = expires_at
    order.handover_verified_at = None
    order.receiver_confirmed_at = None
    order.fulfillment_status = FULFILLMENT_OTP_GENERATED
    db.commit()
    return {"otp": otp, "expires_at": expires_at}


@router.post("/{order_id}/verify-handover-otp", response_model=OrderPublic)
def verify_handover_otp(
    order_id: str,
    payload: HandoverOtpVerify,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Order:
    order = _get_visible_order(db, order_id, current_user)
    _require_order_seller(order, current_user)
    if not order.handover_otp_hash or not order.handover_otp_expires_at:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No active handover OTP",
        )
    if _utc_datetime(order.handover_otp_expires_at) <= datetime.now(timezone.utc):
        order.handover_otp_hash = None
        order.fulfillment_status = FULFILLMENT_PENDING
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Handover OTP has expired",
        )
    expected_hash = _hash_otp(order.id, payload.otp)
    if not hmac.compare_digest(expected_hash, order.handover_otp_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid handover OTP",
        )

    now = datetime.now(timezone.utc)
    order.handover_otp_hash = None
    order.handover_verified_at = now
    order.receiver_confirmed_at = now
    order.fulfillment_status = FULFILLMENT_RECEIVED
    order.status = OrderStatus.completed
    order.completed_at = now
    _mark_order_product_sold(db, order)
    db.commit()
    db.refresh(order)
    return _load_order_details(db, order)


@router.post("/{order_id}/confirm-received", response_model=OrderPublic)
def confirm_order_received(
    order_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Order:
    order = _get_visible_order(db, order_id, current_user)
    _require_order_receiver(order, current_user)
    if order.handover_verified_at is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Handover must be verified before confirming receipt",
        )

    now = datetime.now(timezone.utc)
    order.receiver_confirmed_at = now
    order.fulfillment_status = FULFILLMENT_RECEIVED
    order.status = OrderStatus.completed
    order.completed_at = now
    _mark_order_product_sold(db, order)
    db.commit()
    db.refresh(order)
    return _load_order_details(db, order)


@router.post("/{order_id}/report-dispute", response_model=OrderPublic)
def report_order_dispute(
    order_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Order:
    order = _get_visible_order(db, order_id, current_user)
    _require_order_receiver(order, current_user)
    if order.receiver_confirmed_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot dispute an order that has already been received",
        )

    order.fulfillment_status = FULFILLMENT_DISPUTED
    db.commit()
    db.refresh(order)
    return _load_order_details(db, order)
