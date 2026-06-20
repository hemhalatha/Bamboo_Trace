from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user, require_roles, require_roles_with_complete_profile
from app.models import Project, User, UserRole
from app.schemas import ProductListingPublic, ProjectCreate, ProjectPublic, ProjectUpdate

router = APIRouter(prefix="/projects", tags=["projects"])


def public_location(user: User | None) -> str:
    if user is None:
        return "Not specified"
    parts = [part for part in [user.city, user.district] if part]
    return ", ".join(parts) if parts else "Not specified"


def _effective_project_status(project: Project) -> str:
    raw_status = (project.status or "").strip().lower()
    if raw_status:
        return raw_status
    if project.is_hidden:
        return "draft"
    if project.quantity <= 0:
        return "sold"
    return "available"


def _serialize_listing(product: Project, artisan: User | None) -> dict:
    status_value = _effective_project_status(product)
    return {
        "id": product.id,
        "ownerId": product.owner_id,
        "sourceBatchId": product.source_batch_id,
        "productType": product.product_type,
        "productName": product.product_name,
        "description": product.description,
        "price": product.price,
        "bambooType": product.bamboo_type,
        "materialSource": product.material_source,
        "sourceDetails": product.source_details,
        "quantity": product.quantity,
        "isHidden": product.is_hidden,
        "status": status_value,
        "estimatedDays": product.estimated_days,
        "progress": product.progress,
        "imageUrl": product.image_url,
        "createdAt": product.created_at,
        "artisanName": artisan.name if artisan else "Unknown artisan",
        "artisanLocation": public_location(artisan),
        "artisanCity": artisan.city if artisan else None,
        "artisanDistrict": artisan.district if artisan else None,
    }


@router.get("/catalog", response_model=list[ProductListingPublic])
def list_project_catalog(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    products = list(
        db.scalars(
            select(Project)
            .where(
                Project.is_hidden.is_(False),
                Project.status.in_(["available", "ordered", "sold"]),
            )
            .order_by(Project.created_at.desc())
        )
    )
    listings = []
    for product in products:
        artisan = db.get(User, product.owner_id)
        listings.append(_serialize_listing(product, artisan))
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
    current_user: User = Depends(require_roles_with_complete_profile(UserRole.artisan)),
    db: Session = Depends(get_db),
) -> Project:
    data = payload.model_dump(by_alias=False)
    data["is_hidden"] = data["status"] in {"draft", "archived"} or data["is_hidden"]
    project = Project(owner_id=current_user.id, **data)
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


@router.patch("/{project_id}", response_model=ProjectPublic)
def update_project(
    project_id: str,
    payload: ProjectUpdate,
    current_user: User = Depends(require_roles_with_complete_profile(UserRole.artisan)),
    db: Session = Depends(get_db),
) -> Project:
    project = db.get(Project, project_id)
    if project is None or project.owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found",
        )

    updates = payload.model_dump(by_alias=False, exclude_unset=True)
    for field, value in updates.items():
        setattr(project, field, value)

    if "status" in updates:
        project.is_hidden = updates["status"] in {"draft", "archived"}
    elif "is_hidden" in updates and project.is_hidden:
        project.status = "draft"
    elif project.quantity <= 0 and project.status == "available":
        project.status = "sold"

    db.commit()
    db.refresh(project)
    return project
