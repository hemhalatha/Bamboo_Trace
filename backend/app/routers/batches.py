from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user, require_roles
from app.models import Batch, BatchStatus, User, UserRole
from app.schemas import BatchCreate, BatchPublic, MaterialListingPublic

router = APIRouter(prefix="/batches", tags=["batches"])


@router.get("/catalog", response_model=list[MaterialListingPublic])
def list_batch_catalog(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    batches = list(
        db.scalars(
            select(Batch)
            .where(Batch.status.in_([BatchStatus.available, BatchStatus.upcoming]))
            .order_by(Batch.created_at.desc())
        )
    )
    listings = []
    for batch in batches:
        farmer = db.get(User, batch.owner_id)
        listings.append(
            {
                "id": batch.id,
                "ownerId": batch.owner_id,
                "batchId": batch.batch_id,
                "type": batch.type,
                "quantity": batch.quantity,
                "quantityAvailable": batch.quantity_available,
                "quantityUnit": batch.quantity_unit,
                "price": batch.price,
                "location": batch.location,
                "availableNow": batch.available_now,
                "availableFromDate": batch.available_from_date,
                "expectedHarvestDate": batch.expected_harvest_date,
                "status": batch.status,
                "createdAt": batch.created_at,
                "farmerName": farmer.name if farmer else "Unknown farmer",
                "farmerLocation": batch.location,
            }
        )
    return listings


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
    data = payload.model_dump(by_alias=False)
    data["quantity"] = data["quantity_available"]
    batch = Batch(owner_id=current_user.id, **data)
    db.add(batch)
    db.commit()
    db.refresh(batch)
    return batch
