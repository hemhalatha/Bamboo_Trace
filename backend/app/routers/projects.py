from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import require_roles
from app.models import Project, User, UserRole
from app.schemas import ProjectCreate, ProjectPublic

router = APIRouter(prefix="/projects", tags=["projects"])


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
