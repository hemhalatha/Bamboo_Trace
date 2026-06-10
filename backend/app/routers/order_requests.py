from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models import (
    Batch,
    Notification,
    NotificationType,
    Order,
    OrderRequest,
    OrderStatus,
    Project,
    RequestStatus,
    RequestType,
    User,
    UserRole,
)
from app.schemas import OrderRequestCreate, OrderRequestPublic

router = APIRouter(prefix="/order-requests", tags=["order-requests"])


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def create_notification(
    db: Session,
    *,
    user_id: str,
    notification_type: NotificationType,
    title: str,
    body: str,
    entity_type: str,
    entity_id: str,
) -> None:
    if entity_type == "order_request":
        navigation_target = f"/requests/{entity_id}"
    elif entity_type == "custom_order_request":
        navigation_target = f"/custom-requests/{entity_id}"
    else:
        navigation_target = f"/{entity_type}s/{entity_id}"

    db.add(
        Notification(
            user_id=user_id,
            type=notification_type,
            title=title,
            body=body,
            entity_type=entity_type,
            entity_id=entity_id,
            navigation_target=navigation_target,
        )
    )


def _load_request_details(db: Session, request: OrderRequest) -> OrderRequest:
    request.product = db.get(Project, request.product_id) if request.product_id else None
    request.batch = db.get(Batch, request.batch_id) if request.batch_id else None
    request.order = db.get(Order, request.order_id) if request.order_id else None
    return request


def _visible_request_filter(user: User):
    return or_(
        OrderRequest.sender_id == user.id,
        OrderRequest.receiver_id == user.id,
    )


def _validate_customer_to_artisan(
    db: Session,
    payload: OrderRequestCreate,
    current_user: User,
    receiver: User,
) -> Project:
    if current_user.role != UserRole.customer or receiver.role != UserRole.artisan:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Customer order requests must be sent from a customer to an artisan",
        )
    if not payload.product_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="productId is required for customer order requests",
        )
    product = db.get(Project, payload.product_id)
    if product is None or product.owner_id != receiver.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found for selected artisan",
        )
    return product


def _validate_artisan_to_farmer(
    db: Session,
    payload: OrderRequestCreate,
    current_user: User,
    receiver: User,
) -> Batch | None:
    if current_user.role != UserRole.artisan or receiver.role != UserRole.farmer:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Material requests must be sent from an artisan to a farmer",
        )

    order = db.get(Order, payload.order_id) if payload.order_id else None
    if payload.order_id and (order is None or order.artisan_id != current_user.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Related order not found for artisan",
        )

    batch = db.get(Batch, payload.batch_id) if payload.batch_id else None
    if payload.batch_id and (batch is None or batch.owner_id != receiver.id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Batch not found for selected farmer",
        )

    if batch is None and not payload.notes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Material request requires batchId or notes",
        )
    return batch


def _ensure_no_duplicate_pending(
    db: Session,
    payload: OrderRequestCreate,
    current_user: User,
) -> None:
    duplicate = db.scalar(
        select(OrderRequest).where(
            OrderRequest.request_type == payload.request_type,
            OrderRequest.sender_id == current_user.id,
            OrderRequest.receiver_id == payload.receiver_id,
            OrderRequest.status == RequestStatus.pending,
            OrderRequest.order_id == payload.order_id,
            OrderRequest.product_id == payload.product_id,
            OrderRequest.batch_id == payload.batch_id,
        )
    )
    if duplicate is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A pending request already exists for this selection",
        )


@router.post("", response_model=OrderRequestPublic, status_code=status.HTTP_201_CREATED)
def create_order_request(
    payload: OrderRequestCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OrderRequest:
    receiver = db.get(User, payload.receiver_id)
    if receiver is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Receiver not found",
        )

    if payload.request_type == RequestType.customer_to_artisan:
        _validate_customer_to_artisan(db, payload, current_user, receiver)
    else:
        _validate_artisan_to_farmer(db, payload, current_user, receiver)

    _ensure_no_duplicate_pending(db, payload, current_user)

    order_request = OrderRequest(
        request_type=payload.request_type,
        sender_id=current_user.id,
        receiver_id=receiver.id,
        order_id=payload.order_id,
        product_id=payload.product_id,
        batch_id=payload.batch_id,
        quantity=payload.quantity,
        quantity_unit=payload.quantity_unit,
        notes=payload.notes,
    )
    db.add(order_request)
    db.flush()
    create_notification(
        db,
        user_id=receiver.id,
        notification_type=NotificationType.request_created,
        title="New request",
        body=f"{current_user.name} sent you a request",
        entity_type="order_request",
        entity_id=order_request.id,
    )
    db.commit()
    db.refresh(order_request)
    return _load_request_details(db, order_request)


@router.get("/active", response_model=list[OrderRequestPublic])
def list_active_requests(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[OrderRequest]:
    requests = list(
        db.scalars(
            select(OrderRequest)
            .where(
                _visible_request_filter(current_user),
                OrderRequest.status == RequestStatus.pending,
            )
            .order_by(OrderRequest.created_at.desc())
        )
    )
    return [_load_request_details(db, request) for request in requests]


@router.get("/history", response_model=list[OrderRequestPublic])
def list_request_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[OrderRequest]:
    requests = list(
        db.scalars(
            select(OrderRequest)
            .where(
                _visible_request_filter(current_user),
                OrderRequest.status != RequestStatus.pending,
            )
            .order_by(OrderRequest.responded_at.desc(), OrderRequest.created_at.desc())
        )
    )
    return [_load_request_details(db, request) for request in requests]


def _get_pending_request_for_response(
    db: Session,
    request_id: str,
    current_user: User,
) -> OrderRequest:
    order_request = db.get(OrderRequest, request_id)
    if order_request is None or order_request.receiver_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pending request not found",
        )
    if order_request.status != RequestStatus.pending:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Request has already been responded to",
        )
    return order_request


def _create_or_update_customer_order(db: Session, order_request: OrderRequest) -> Order:
    product = db.get(Project, order_request.product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product no longer exists",
        )

    order = None
    if order_request.order_id:
        order = db.get(Order, order_request.order_id)
    if order is None:
        order = db.scalar(
            select(Order).where(Order.source_request_id == order_request.id)
        )
    if order is None:
        order = Order(
            owner_id=order_request.sender_id,
            customer_id=order_request.sender_id,
            artisan_id=order_request.receiver_id,
            source_request_id=order_request.id,
            product_id=product.id,
            product_name=product.product_name,
            product_type=product.product_type,
            quantity=order_request.quantity,
            quantity_unit=order_request.quantity_unit,
            notes=order_request.notes,
            status=OrderStatus.accepted,
            accepted_at=now_utc(),
        )
        db.add(order)
        db.flush()
    else:
        order.customer_id = order_request.sender_id
        order.artisan_id = order_request.receiver_id
        order.product_id = product.id
        order.product_name = product.product_name
        order.product_type = product.product_type
        order.quantity = order_request.quantity
        order.quantity_unit = order_request.quantity_unit
        order.notes = order_request.notes
        order.status = OrderStatus.accepted
        order.accepted_at = now_utc()
    order_request.order_id = order.id
    return order


def _update_order_with_farmer(db: Session, order_request: OrderRequest) -> Order | None:
    if not order_request.order_id:
        return None
    order = db.get(Order, order_request.order_id)
    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Related order no longer exists",
        )
    order.farmer_id = order_request.receiver_id
    return order


@router.post("/{request_id}/accept", response_model=OrderRequestPublic)
def accept_order_request(
    request_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OrderRequest:
    order_request = _get_pending_request_for_response(db, request_id, current_user)
    order_request.status = RequestStatus.accepted
    order_request.responded_at = now_utc()

    if order_request.request_type == RequestType.customer_to_artisan:
        order = _create_or_update_customer_order(db, order_request)
    else:
        order = _update_order_with_farmer(db, order_request)

    create_notification(
        db,
        user_id=order_request.sender_id,
        notification_type=NotificationType.request_accepted,
        title="Request accepted",
        body=f"{current_user.name} accepted your request",
        entity_type="order" if order else "order_request",
        entity_id=order.id if order else order_request.id,
    )
    if order:
        participant_ids = {
            user_id
            for user_id in [order.customer_id, order.artisan_id, order.farmer_id]
            if user_id and user_id != order_request.sender_id
        }
        for user_id in participant_ids:
            create_notification(
                db,
                user_id=user_id,
                notification_type=NotificationType.request_accepted,
                title="Order updated",
                body="An order you are linked to was updated",
                entity_type="order",
                entity_id=order.id,
            )
    db.commit()
    db.refresh(order_request)
    return _load_request_details(db, order_request)


@router.post("/{request_id}/reject", response_model=OrderRequestPublic)
def reject_order_request(
    request_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OrderRequest:
    order_request = _get_pending_request_for_response(db, request_id, current_user)
    order_request.status = RequestStatus.rejected
    order_request.responded_at = now_utc()
    create_notification(
        db,
        user_id=order_request.sender_id,
        notification_type=NotificationType.request_rejected,
        title="Request rejected",
        body=f"{current_user.name} rejected your request",
        entity_type="order_request",
        entity_id=order_request.id,
    )
    db.commit()
    db.refresh(order_request)
    return _load_request_details(db, order_request)
