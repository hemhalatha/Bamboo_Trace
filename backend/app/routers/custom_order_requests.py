from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user, require_complete_profile
from app.models import (
    CustomOrderRequest,
    CustomRequestStatus,
    CustomRequestTargetType,
    NotificationType,
    Order,
    OrderStatus,
    OrderType,
    User,
    UserRole,
)
from app.routers.order_requests import create_notification
from app.schemas import CustomOrderRequestCreate, CustomOrderRequestPublic

router = APIRouter(prefix="/custom-order-requests", tags=["custom-order-requests"])


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _visible_custom_request_filter(user: User):
    if user.role == UserRole.customer:
        return CustomOrderRequest.customer_id == user.id
    if user.role == UserRole.artisan:
        return or_(
            CustomOrderRequest.target_artisan_id == user.id,
            CustomOrderRequest.target_type == CustomRequestTargetType.broadcast,
        )
    return CustomOrderRequest.id == ""


def _rejected_artisan_ids(request: CustomOrderRequest) -> set[str]:
    raw_ids = request.rejected_artisan_ids or ""
    return {artisan_id for artisan_id in raw_ids.split(",") if artisan_id}


def _has_rejected(request: CustomOrderRequest, user: User) -> bool:
    return user.id in _rejected_artisan_ids(request)


def _add_rejection(request: CustomOrderRequest, user: User) -> None:
    rejected_ids = _rejected_artisan_ids(request)
    rejected_ids.add(user.id)
    request.rejected_artisan_ids = ",".join(sorted(rejected_ids))


def _is_active_for_user(request: CustomOrderRequest, user: User) -> bool:
    if request.status != CustomRequestStatus.open:
        return False
    if user.role == UserRole.artisan and request.target_type == CustomRequestTargetType.broadcast:
        return not _has_rejected(request, user)
    return True


def _is_history_for_user(request: CustomOrderRequest, user: User) -> bool:
    if user.role == UserRole.customer:
        return request.status != CustomRequestStatus.open
    if user.role != UserRole.artisan:
        return False
    if request.target_type == CustomRequestTargetType.broadcast:
        return request.status != CustomRequestStatus.open or _has_rejected(request, user)
    return request.status != CustomRequestStatus.open


def _load_details(
    db: Session,
    request: CustomOrderRequest,
    current_user: User,
) -> CustomOrderRequest:
    request.order = db.get(Order, request.order_id) if request.order_id else None
    request.rejected_by_current_user = _has_rejected(request, current_user)
    return request


@router.post(
    "",
    response_model=CustomOrderRequestPublic,
    status_code=status.HTTP_201_CREATED,
)
def create_custom_order_request(
    payload: CustomOrderRequestCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CustomOrderRequest:
    if current_user.role != UserRole.customer:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only customers can create custom requests",
        )
    require_complete_profile(current_user)
    artisan: User | None = None
    if payload.target_type == CustomRequestTargetType.specific_artisan:
        artisan = db.get(User, payload.target_artisan_id)
        if artisan is None or artisan.role != UserRole.artisan:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Target artisan not found",
            )

    request = CustomOrderRequest(
        customer_id=current_user.id,
        target_type=payload.target_type,
        target_artisan_id=artisan.id if artisan else None,
        title=payload.title,
        description=payload.description,
        quantity=payload.quantity,
        budget=payload.budget,
        deadline=payload.deadline,
        image_url=payload.image_url,
    )
    db.add(request)
    db.flush()
    if artisan is not None:
        create_notification(
            db,
            user_id=artisan.id,
            notification_type=NotificationType.request_created,
            title="New custom request",
            body=f"{current_user.name} sent a custom product request",
            entity_type="custom_order_request",
            entity_id=request.id,
        )
    else:
        artisans = list(db.scalars(select(User).where(User.role == UserRole.artisan)))
        for broadcast_artisan in artisans:
            create_notification(
                db,
                user_id=broadcast_artisan.id,
                notification_type=NotificationType.request_created,
                title="New broadcast custom request",
                body=f"{current_user.name} broadcast a custom product request",
                entity_type="custom_order_request",
                entity_id=request.id,
            )
    db.commit()
    db.refresh(request)
    return _load_details(db, request, current_user)


@router.get("/active", response_model=list[CustomOrderRequestPublic])
def list_active_custom_requests(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CustomOrderRequest]:
    visible_requests = list(
        db.scalars(
            select(CustomOrderRequest)
            .where(
                _visible_custom_request_filter(current_user),
                CustomOrderRequest.status == CustomRequestStatus.open,
            )
            .order_by(CustomOrderRequest.created_at.desc())
        )
    )
    return [
        _load_details(db, request, current_user)
        for request in visible_requests
        if _is_active_for_user(request, current_user)
    ]


@router.get("/history", response_model=list[CustomOrderRequestPublic])
def list_custom_request_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CustomOrderRequest]:
    visible_requests = list(
        db.scalars(
            select(CustomOrderRequest)
            .where(
                _visible_custom_request_filter(current_user),
            )
            .order_by(
                CustomOrderRequest.responded_at.desc(),
                CustomOrderRequest.created_at.desc(),
            )
        )
    )
    return [
        _load_details(db, request, current_user)
        for request in visible_requests
        if _is_history_for_user(request, current_user)
    ]


@router.get("/{request_id}", response_model=CustomOrderRequestPublic)
def get_custom_order_request(
    request_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CustomOrderRequest:
    request = db.scalar(
        select(CustomOrderRequest).where(
            CustomOrderRequest.id == request_id,
            _visible_custom_request_filter(current_user),
        )
    )
    if request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Custom request not found",
        )
    return _load_details(db, request, current_user)


def _get_open_custom_request(
    db: Session,
    request_id: str,
    current_user: User,
) -> CustomOrderRequest:
    if current_user.role != UserRole.artisan:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only artisans can respond to custom requests",
        )
    request = db.scalar(
        select(CustomOrderRequest)
        .where(CustomOrderRequest.id == request_id)
        .with_for_update()
    )
    if request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Custom request not found",
        )
    if request.target_type == CustomRequestTargetType.specific_artisan:
        if request.target_artisan_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Custom request not found",
            )
    elif request.target_type == CustomRequestTargetType.broadcast:
        if _has_rejected(request, current_user):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You have already rejected this broadcast request",
            )
    if request.status != CustomRequestStatus.open:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Custom request has already been responded to",
        )
    return request


@router.post("/{request_id}/accept", response_model=CustomOrderRequestPublic)
def accept_custom_order_request(
    request_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CustomOrderRequest:
    request = _get_open_custom_request(db, request_id, current_user)
    require_complete_profile(current_user)
    request.status = CustomRequestStatus.accepted
    request.accepted_by_artisan_id = current_user.id
    request.responded_at = now_utc()

    order = Order(
        owner_id=request.customer_id,
        customer_id=request.customer_id,
        artisan_id=current_user.id,
        source_request_id=request.id,
        product_name=request.title,
        product_type="custom",
        order_type=OrderType.custom_product_order,
        quantity=request.quantity,
        quantity_unit="item",
        notes=request.description,
        price=request.budget or 0,
        status=OrderStatus.accepted,
        accepted_at=now_utc(),
    )
    db.add(order)
    db.flush()
    request.order_id = order.id
    create_notification(
        db,
        user_id=request.customer_id,
        notification_type=NotificationType.request_accepted,
        title="Custom request accepted",
        body=f"{current_user.name} accepted your custom request",
        entity_type="order",
        entity_id=order.id,
    )
    db.commit()
    db.refresh(request)
    return _load_details(db, request, current_user)


@router.post("/{request_id}/reject", response_model=CustomOrderRequestPublic)
def reject_custom_order_request(
    request_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> CustomOrderRequest:
    request = _get_open_custom_request(db, request_id, current_user)
    if request.target_type == CustomRequestTargetType.broadcast:
        _add_rejection(request, current_user)
    else:
        request.status = CustomRequestStatus.rejected
    request.responded_at = now_utc()
    create_notification(
        db,
        user_id=request.customer_id,
        notification_type=NotificationType.request_rejected,
        title="Custom request rejected",
        body=f"{current_user.name} rejected your custom request",
        entity_type="custom_order_request",
        entity_id=request.id,
    )
    db.commit()
    db.refresh(request)
    return _load_details(db, request, current_user)
