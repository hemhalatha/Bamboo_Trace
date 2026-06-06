import re
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.models import UserRole


class UserPublic(BaseModel):
    id: str
    email: EmailStr
    name: str
    role: UserRole
    created_at: datetime

    model_config = {"from_attributes": True}


class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=1, max_length=120)
    role: UserRole

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if not re.search(r"[A-Z]", value):
            raise ValueError("Password must contain an uppercase letter")
        if not re.search(r"[a-z]", value):
            raise ValueError("Password must contain a lowercase letter")
        if not re.search(r"\d", value):
            raise ValueError("Password must contain a number")
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserPublic


class BatchCreate(BaseModel):
    batch_id: str = Field(alias="batchId", min_length=1, max_length=80)
    type: str = Field(min_length=1, max_length=80)
    quantity: int = Field(gt=0)
    location: str = Field(min_length=1, max_length=255)

    model_config = {"populate_by_name": True}


class BatchPublic(BatchCreate):
    id: str
    created_at: datetime = Field(alias="createdAt")

    model_config = {"from_attributes": True, "populate_by_name": True}


class ProjectCreate(BaseModel):
    source_batch_id: str = Field(alias="sourceBatchId", min_length=1, max_length=80)
    product_type: str = Field(alias="productType", min_length=1, max_length=80)
    product_name: str = Field(alias="productName", min_length=1, max_length=160)
    quantity: int = Field(gt=0)
    estimated_days: int = Field(alias="estimatedDays", gt=0)
    progress: float = Field(ge=0, le=1)

    model_config = {"populate_by_name": True}


class ProjectPublic(ProjectCreate):
    id: str
    created_at: datetime = Field(alias="createdAt")

    model_config = {"from_attributes": True, "populate_by_name": True}


class OrderCreate(BaseModel):
    product_name: str = Field(alias="productName", min_length=1, max_length=160)
    status: str = Field(min_length=1, max_length=80)
    price: float = Field(ge=0)
    artisan_id: str | None = Field(default=None, alias="artisanId")

    model_config = {"populate_by_name": True}


class OrderPublic(OrderCreate):
    id: str
    created_at: datetime = Field(alias="createdAt")

    model_config = {"from_attributes": True, "populate_by_name": True}
