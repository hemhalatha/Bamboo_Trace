from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import require_roles
from app.models import Batch, User, UserRole
from app.schemas import BatchCreate, BatchPublic

router = APIRouter(prefix="/batches", tags=["batches"])


@router.get("", response_model=list[BatchPublic])
def list_batches(
    current_user: User = Depends(require_roles(UserRole.farmer)),
    db: Session = Depends(get_db),
) -> list[Batch]:
    return list(
        db.scalars(
            select(Batch)
            .where(Batch.owner_id == current_user.id)
            .order_by(Batch.created_at.desc())
        )
    )


@router.post("", response_model=BatchPublic, status_code=status.HTTP_201_CREATED)
def create_batch(
    payload: BatchCreate,
    current_user: User = Depends(require_roles(UserRole.farmer)),
    db: Session = Depends(get_db),
) -> Batch:
    batch = Batch(owner_id=current_user.id, **payload.model_dump(by_alias=False))
    db.add(batch)
    db.commit()
    db.refresh(batch)
    return batch
