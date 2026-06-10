from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models import User, UserRole
from app.schemas import ArtisanPublic

router = APIRouter(prefix="/users", tags=["users"])


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
            "location": "Not specified",
        }
        for artisan in artisans
    ]
