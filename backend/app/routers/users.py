from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models import User, UserRole
from app.profile_completion import PROFILE_FIELDS, profile_completion_message
from app.schemas import ArtisanPublic, UserProfileUpdate, UserPublic

router = APIRouter(prefix="/users", tags=["users"])


def public_location(user: User) -> str:
    parts = [part for part in [user.city, user.district] if part]
    return ", ".join(parts) if parts else "Not specified"


@router.patch("/me/profile", response_model=UserPublic)
def update_my_profile(
    payload: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    updates = payload.model_dump(by_alias=False, exclude_unset=True)
    candidate = {
        field: updates.get(field, getattr(current_user, field, None))
        for field in PROFILE_FIELDS
    }
    missing_fields = [
        field
        for field, value in candidate.items()
        if value is None or str(value).strip() == ""
    ]
    if missing_fields:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "message": profile_completion_message(current_user.role),
                "profileRequired": True,
                "missingFields": missing_fields,
            },
        )

    for field, value in updates.items():
        setattr(current_user, field, value)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/artisans", response_model=list[ArtisanPublic])
def list_artisans(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    artisans = list(
        db.scalars(
            select(User)
            .where(User.role == UserRole.artisan)
            .order_by(User.name.asc())
        )
    )
    return [
        {
            "id": artisan.id,
            "name": artisan.name,
            "email": artisan.email,
            "role": artisan.role,
            "location": public_location(artisan),
            "city": artisan.city,
            "district": artisan.district,
        }
        for artisan in artisans
    ]
