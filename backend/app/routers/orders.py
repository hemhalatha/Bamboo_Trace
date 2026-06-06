from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import require_roles
from app.models import Order, User, UserRole
from app.schemas import OrderCreate, OrderPublic

router = APIRouter(prefix="/orders", tags=["orders"])


@router.get("", response_model=list[OrderPublic])
def list_orders(
    current_user: User = Depends(require_roles(UserRole.customer)),
    db: Session = Depends(get_db),
) -> list[Order]:
    return list(
        db.scalars(
            select(Order)
            .where(Order.owner_id == current_user.id)
            .order_by(Order.created_at.desc())
        )
    )


@router.post("", response_model=OrderPublic, status_code=status.HTTP_201_CREATED)
def create_order(
    payload: OrderCreate,
    current_user: User = Depends(require_roles(UserRole.customer)),
    db: Session = Depends(get_db),
) -> Order:
    order = Order(owner_id=current_user.id, **payload.model_dump(by_alias=False))
    db.add(order)
    db.commit()
    db.refresh(order)
    return order
