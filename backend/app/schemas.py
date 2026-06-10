import re
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator

from app.models import (
    NotificationType,
    OrderStatus,
    OrderType,
    BatchStatus,
    CustomRequestStatus,
    CustomRequestTargetType,
    RequestStatus,
    RequestType,
    UserRole,
)


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
    password: str = Field(min_length=1, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserPublic


class BatchCreate(BaseModel):
    batch_id: str = Field(alias="batchId", min_length=1, max_length=80)
    type: str = Field(min_length=1, max_length=80)
    quantity: int | None = Field(default=None, ge=0)
    quantity_available: int | None = Field(default=None, alias="quantityAvailable", ge=0)
    quantity_unit: str = Field(default="kg", alias="quantityUnit", min_length=1, max_length=40)
    price: float | None = Field(default=None, ge=0)
    location: str = Field(min_length=1, max_length=255)
    available_now: bool = Field(default=True, alias="availableNow")
    available_from_date: datetime | None = Field(default=None, alias="availableFromDate")
    expected_harvest_date: datetime | None = Field(default=None, alias="expectedHarvestDate")
    status: BatchStatus | None = None

    model_config = {"populate_by_name": True}

    @model_validator(mode="after")
    def validate_availability(self) -> "BatchCreate":
        if self.quantity_available is None:
            self.quantity_available = self.quantity if self.quantity is not None else 0
        if self.quantity is None:
            self.quantity = self.quantity_available

        if self.status is None:
            if (
                not self.available_now
                or (
                    self.quantity_available == 0
                    and (
                        self.expected_harvest_date is not None
                        or self.available_from_date is not None
                    )
                )
            ):
                self.status = BatchStatus.upcoming
            elif self.quantity_available == 0:
                self.status = BatchStatus.sold_out
            else:
                self.status = BatchStatus.available

        if self.status == BatchStatus.upcoming:
            self.available_now = False
            if self.expected_harvest_date is None and self.available_from_date is None:
                raise ValueError(
                    "Upcoming listings require expectedHarvestDate or availableFromDate"
                )
            upcoming_date = self.expected_harvest_date or self.available_from_date
            if upcoming_date is not None:
                now = datetime.now(upcoming_date.tzinfo)
                if upcoming_date <= now:
                    raise ValueError("Upcoming availability dates must be in the future")

        if not self.available_now and self.status == BatchStatus.available:
            raise ValueError("available listings must be available now")

        return self


class BatchPublic(BatchCreate):
    id: str
    owner_id: str = Field(alias="ownerId")
    created_at: datetime = Field(alias="createdAt")

    model_config = {"from_attributes": True, "populate_by_name": True}


class MaterialListingPublic(BatchPublic):
    farmer_name: str = Field(alias="farmerName")
    farmer_location: str = Field(alias="farmerLocation")

    model_config = {"populate_by_name": True}


class ProjectCreate(BaseModel):
    source_batch_id: str = Field(alias="sourceBatchId", min_length=1, max_length=80)
    product_type: str = Field(alias="productType", min_length=1, max_length=80)
    product_name: str = Field(alias="productName", min_length=1, max_length=160)
    quantity: int = Field(gt=0)
    is_hidden: bool = Field(default=False, alias="isHidden")
    estimated_days: int = Field(alias="estimatedDays", gt=0)
    progress: float = Field(ge=0, le=1)

    model_config = {"populate_by_name": True}


class ProjectPublic(ProjectCreate):
    id: str
    owner_id: str = Field(alias="ownerId")
    created_at: datetime = Field(alias="createdAt")

    model_config = {"from_attributes": True, "populate_by_name": True}


class ProductListingPublic(ProjectPublic):
    artisan_name: str = Field(alias="artisanName")
    artisan_location: str = Field(default="Not specified", alias="artisanLocation")

    model_config = {"populate_by_name": True}


class OrderCreate(BaseModel):
    product_name: str = Field(alias="productName", min_length=1, max_length=160)
    status: OrderStatus = OrderStatus.pending
    price: float = Field(ge=0)
    artisan_id: str | None = Field(default=None, alias="artisanId")
    order_type: OrderType = Field(default=OrderType.product_order, alias="orderType")
    quantity: int = Field(default=1, gt=0)
    quantity_unit: str = Field(default="item", alias="quantityUnit", min_length=1, max_length=40)
    fulfillment_type: str | None = Field(default=None, alias="fulfillmentType", max_length=80)

    model_config = {"populate_by_name": True}


class OrderPublic(OrderCreate):
    id: str
    customer_id: str | None = Field(default=None, alias="customerId")
    farmer_id: str | None = Field(default=None, alias="farmerId")
    source_request_id: str | None = Field(default=None, alias="sourceRequestId")
    product_id: str | None = Field(default=None, alias="productId")
    batch_id: str | None = Field(default=None, alias="batchId")
    product_type: str | None = Field(default=None, alias="productType")
    fulfillment_status: str = Field(default="pending_handover", alias="fulfillmentStatus")
    notes: str | None = None
    created_at: datetime = Field(alias="createdAt")
    accepted_at: datetime | None = Field(default=None, alias="acceptedAt")
    rejected_at: datetime | None = Field(default=None, alias="rejectedAt")
    completed_at: datetime | None = Field(default=None, alias="completedAt")
    handover_otp_expires_at: datetime | None = Field(
        default=None, alias="handoverOtpExpiresAt"
    )
    handover_verified_at: datetime | None = Field(default=None, alias="handoverVerifiedAt")
    receiver_confirmed_at: datetime | None = Field(
        default=None, alias="receiverConfirmedAt"
    )

    model_config = {"from_attributes": True, "populate_by_name": True}


class ProductOrderCreate(BaseModel):
    product_id: str = Field(alias="productId", min_length=1, max_length=36)
    quantity: int = Field(gt=0)
    quantity_unit: str = Field(alias="quantityUnit", min_length=1, max_length=40)
    fulfillment_type: str = Field(alias="fulfillmentType", min_length=1, max_length=80)

    model_config = {"populate_by_name": True}


class MaterialOrderCreate(BaseModel):
    batch_id: str = Field(alias="batchId", min_length=1, max_length=36)
    quantity: int = Field(gt=0)
    quantity_unit: str = Field(alias="quantityUnit", min_length=1, max_length=40)
    fulfillment_type: str = Field(alias="fulfillmentType", min_length=1, max_length=80)

    model_config = {"populate_by_name": True}


class OrderStatusUpdate(BaseModel):
    status: OrderStatus


class HandoverOtpPublic(BaseModel):
    otp: str
    expires_at: datetime = Field(alias="expiresAt")

    model_config = {"populate_by_name": True}


class HandoverOtpVerify(BaseModel):
    otp: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")


class OrderRequestCreate(BaseModel):
    request_type: RequestType = Field(alias="requestType")
    receiver_id: str = Field(alias="receiverId", min_length=1, max_length=36)
    order_id: str | None = Field(default=None, alias="orderId", max_length=36)
    product_id: str | None = Field(default=None, alias="productId", max_length=36)
    batch_id: str | None = Field(default=None, alias="batchId", max_length=36)
    quantity: int = Field(gt=0)
    quantity_unit: str = Field(default="item", alias="quantityUnit", min_length=1, max_length=40)
    notes: str | None = Field(default=None, max_length=1000)

    model_config = {"populate_by_name": True}


class UserSummary(BaseModel):
    id: str
    name: str
    email: EmailStr
    role: UserRole

    model_config = {"from_attributes": True}


class ArtisanPublic(BaseModel):
    id: str
    name: str
    email: EmailStr
    role: UserRole
    location: str = "Not specified"

    model_config = {"from_attributes": True}


class OrderRequestPublic(BaseModel):
    id: str
    request_type: RequestType = Field(alias="requestType")
    sender_id: str = Field(alias="senderId")
    receiver_id: str = Field(alias="receiverId")
    order_id: str | None = Field(default=None, alias="orderId")
    product_id: str | None = Field(default=None, alias="productId")
    batch_id: str | None = Field(default=None, alias="batchId")
    quantity: int
    quantity_unit: str = Field(alias="quantityUnit")
    notes: str | None = None
    status: RequestStatus
    created_at: datetime = Field(alias="createdAt")
    responded_at: datetime | None = Field(default=None, alias="respondedAt")
    sender: UserSummary | None = None
    receiver: UserSummary | None = None
    product: ProjectPublic | None = None
    batch: BatchPublic | None = None
    order: OrderPublic | None = None

    model_config = {"from_attributes": True, "populate_by_name": True}


class CustomOrderRequestCreate(BaseModel):
    target_type: CustomRequestTargetType = Field(
        default=CustomRequestTargetType.specific_artisan, alias="targetType"
    )
    target_artisan_id: str | None = Field(
        default=None, alias="targetArtisanId", min_length=1, max_length=36
    )
    title: str = Field(min_length=1, max_length=160)
    description: str = Field(min_length=1, max_length=1000)
    quantity: int = Field(gt=0)
    budget: float | None = Field(default=None, ge=0)
    deadline: datetime | None = None

    model_config = {"populate_by_name": True}

    @model_validator(mode="after")
    def validate_target(self) -> "CustomOrderRequestCreate":
        if (
            self.target_type == CustomRequestTargetType.specific_artisan
            and self.target_artisan_id is None
        ):
            raise ValueError("targetArtisanId is required for specific artisan requests")
        if (
            self.target_type == CustomRequestTargetType.broadcast
            and self.target_artisan_id is not None
        ):
            raise ValueError("targetArtisanId must be omitted for broadcast requests")
        return self


class CustomOrderRequestPublic(BaseModel):
    id: str
    customer_id: str = Field(alias="customerId")
    target_type: CustomRequestTargetType = Field(alias="targetType")
    target_artisan_id: str | None = Field(default=None, alias="targetArtisanId")
    accepted_by_artisan_id: str | None = Field(default=None, alias="acceptedByArtisanId")
    order_id: str | None = Field(default=None, alias="orderId")
    title: str
    description: str
    quantity: int
    budget: float | None = None
    deadline: datetime | None = None
    status: CustomRequestStatus
    created_at: datetime = Field(alias="createdAt")
    responded_at: datetime | None = Field(default=None, alias="respondedAt")
    rejected_by_current_user: bool = Field(default=False, alias="rejectedByCurrentUser")
    customer: UserSummary | None = None
    target_artisan: UserSummary | None = Field(default=None, alias="targetArtisan")
    accepted_by_artisan: UserSummary | None = Field(default=None, alias="acceptedByArtisan")
    order: OrderPublic | None = None

    model_config = {"from_attributes": True, "populate_by_name": True}


class NotificationPublic(BaseModel):
    id: str
    user_id: str = Field(alias="userId")
    type: NotificationType
    title: str
    body: str
    entity_type: str = Field(alias="entityType")
    entity_id: str = Field(alias="entityId")
    navigation_target: str = Field(alias="navigationTarget")
    read_at: datetime | None = Field(default=None, alias="readAt")
    created_at: datetime = Field(alias="createdAt")

    model_config = {"from_attributes": True, "populate_by_name": True}
