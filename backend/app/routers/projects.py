from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user, require_roles
from app.models import Project, User, UserRole
from app.schemas import ProductListingPublic, ProjectCreate, ProjectPublic

router = APIRouter(prefix="/projects", tags=["projects"])


@router.get("/catalog", response_model=list[ProductListingPublic])
def list_project_catalog(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    products = list(
        db.scalars(
            select(Project)
            .where(Project.is_hidden.is_(False), Project.quantity > 0)
            .order_by(Project.created_at.desc())
        )
    )
    listings = []
    for product in products:
        artisan = db.get(User, product.owner_id)
        listings.append(
            {
                "id": product.id,
                "ownerId": product.owner_id,
                "sourceBatchId": product.source_batch_id,
                "productType": product.product_type,
                "productName": product.product_name,
                "quantity": product.quantity,
                "isHidden": product.is_hidden,
                "estimatedDays": product.estimated_days,
                "progress": product.progress,
                "createdAt": product.created_at,
                "artisanName": artisan.name if artisan else "Unknown artisan",
                "artisanLocation": "Not specified",
            }
        )
    return listings


@router.get("", response_model=list[ProjectPublic])
def list_projects(
    current_user: User = Depends(require_roles(UserRole.artisan)),
    db: Session = Depends(get_db),
) -> list[Project]:
    return list(
        db.scalars(
            select(Project)
            .where(Project.owner_id == current_user.id)
            .order_by(Project.created_at.desc())
        )
    )


@router.post("", response_model=ProjectPublic, status_code=status.HTTP_201_CREATED)
def create_project(
    payload: ProjectCreate,
    current_user: User = Depends(require_roles(UserRole.artisan)),
    db: Session = Depends(get_db),
) -> Project:
    project = Project(owner_id=current_user.id, **payload.model_dump(by_alias=False))
    db.add(project)
    db.commit()
    db.refresh(project)
    return project
