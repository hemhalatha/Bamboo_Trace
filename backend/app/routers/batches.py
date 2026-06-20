from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user, require_roles, require_roles_with_complete_profile
from app.models import Batch, BatchStatus, User, UserRole
from app.schemas import BatchCreate, BatchPublic, MaterialListingPublic

router = APIRouter(prefix="/batches", tags=["batches"])


def public_location(user: User | None, fallback: str | None = None) -> str:
    if user is not None:
        parts = [part for part in [user.city, user.district] if part]
        if parts:
            return ", ".join(parts)
    return fallback or "Not specified"


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
                "imageUrl": batch.image_url,
                "availableNow": batch.available_now,
                "availableFromDate": batch.available_from_date,
                "expectedHarvestDate": batch.expected_harvest_date,
                "status": batch.status,
                "createdAt": batch.created_at,
                "farmerName": farmer.name if farmer else "Unknown farmer",
                "farmerLocation": public_location(farmer, batch.location),
                "farmerCity": farmer.city if farmer else None,
                "farmerDistrict": farmer.district if farmer else None,
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


@router.get("/{batch_id}", response_model=MaterialListingPublic)
def get_batch(
    batch_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    batch = db.get(Batch, batch_id)
    if batch is None or (
        batch.owner_id != current_user.id
        and batch.status not in [BatchStatus.available, BatchStatus.upcoming]
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Batch not found",
        )
    farmer = db.get(User, batch.owner_id)
    return {
        "id": batch.id,
        "ownerId": batch.owner_id,
        "batchId": batch.batch_id,
        "type": batch.type,
        "quantity": batch.quantity,
        "quantityAvailable": batch.quantity_available,
        "quantityUnit": batch.quantity_unit,
        "price": batch.price,
        "location": batch.location,
        "imageUrl": batch.image_url,
        "availableNow": batch.available_now,
        "availableFromDate": batch.available_from_date,
        "expectedHarvestDate": batch.expected_harvest_date,
        "status": batch.status,
        "createdAt": batch.created_at,
        "farmerName": farmer.name if farmer else "Unknown farmer",
        "farmerLocation": public_location(farmer, batch.location),
        "farmerCity": farmer.city if farmer else None,
        "farmerDistrict": farmer.district if farmer else None,
    }


@router.post("", response_model=BatchPublic, status_code=status.HTTP_201_CREATED)
def create_batch(
    payload: BatchCreate,
    current_user: User = Depends(require_roles_with_complete_profile(UserRole.farmer)),
    db: Session = Depends(get_db),
) -> Batch:
    data = payload.model_dump(by_alias=False)
    data["quantity"] = data["quantity_available"]
    batch = Batch(owner_id=current_user.id, **data)
    db.add(batch)
    db.commit()
    db.refresh(batch)
    return batch
