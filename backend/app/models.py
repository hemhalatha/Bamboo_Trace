import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Enum, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class UserRole(str, enum.Enum):
    farmer = "farmer"
    artisan = "artisan"
    customer = "customer"


class RequestType(str, enum.Enum):
    customer_to_artisan = "customer_to_artisan"
    artisan_to_farmer = "artisan_to_farmer"


class RequestStatus(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"


class OrderStatus(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    rejected = "rejected"
    in_progress = "in_progress"
    completed = "completed"


class OrderType(str, enum.Enum):
    product_order = "product_order"
    material_order = "material_order"
    custom_product_order = "custom_product_order"
    custom_request = "custom_request"


class BatchStatus(str, enum.Enum):
    available = "available"
    upcoming = "upcoming"
    sold_out = "sold_out"
    hidden = "hidden"


class CustomRequestTargetType(str, enum.Enum):
    specific_artisan = "specific_artisan"
    broadcast = "broadcast"


class CustomRequestStatus(str, enum.Enum):
    open = "open"
    accepted = "accepted"
    rejected = "rejected"


class NotificationType(str, enum.Enum):
    request_created = "request_created"
    request_accepted = "request_accepted"
    request_rejected = "request_rejected"
    order_status_changed = "order_status_changed"


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(120))
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), index=True)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    address_line: Mapped[str | None] = mapped_column(String(255), nullable=True)
    city: Mapped[str | None] = mapped_column(String(120), nullable=True)
    district: Mapped[str | None] = mapped_column(String(120), nullable=True)
    state: Mapped[str | None] = mapped_column(String(120), nullable=True)
    pincode: Mapped[str | None] = mapped_column(String(20), nullable=True)
    landmark: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    batches: Mapped[list["Batch"]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )
    projects: Mapped[list["Project"]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )
    orders: Mapped[list["Order"]] = relationship(
        back_populates="owner", cascade="all, delete-orphan"
    )


class Batch(Base):
    __tablename__ = "batches"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    owner_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    batch_id: Mapped[str] = mapped_column(String(80))
    type: Mapped[str] = mapped_column(String(80))
    quantity: Mapped[int] = mapped_column(Integer)
    quantity_available: Mapped[int] = mapped_column(Integer, default=0)
    quantity_unit: Mapped[str] = mapped_column(String(40), default="kg")
    price: Mapped[float | None] = mapped_column(Float, nullable=True)
    location: Mapped[str] = mapped_column(String(255))
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    available_now: Mapped[bool] = mapped_column(Boolean, default=True)
    status: Mapped[BatchStatus] = mapped_column(
        Enum(BatchStatus), default=BatchStatus.available, index=True
    )
    available_from_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    expected_harvest_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    owner: Mapped[User] = relationship(back_populates="batches")


class Project(Base):
    __tablename__ = "projects"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    owner_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    source_batch_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    product_type: Mapped[str] = mapped_column(String(80))
    product_name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    price: Mapped[float | None] = mapped_column(Float, nullable=True)
    bamboo_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    material_source: Mapped[str | None] = mapped_column(String(80), nullable=True)
    source_details: Mapped[str | None] = mapped_column(String(500), nullable=True)
    quantity: Mapped[int] = mapped_column(Integer)
    is_hidden: Mapped[bool] = mapped_column(default=False)
    status: Mapped[str] = mapped_column(String(40), default="available", index=True)
    estimated_days: Mapped[int] = mapped_column(Integer)
    progress: Mapped[float] = mapped_column(Float, default=0)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    owner: Mapped[User] = relationship(back_populates="projects")


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    owner_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    customer_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    artisan_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    farmer_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    source_request_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    product_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    batch_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    product_name: Mapped[str] = mapped_column(String(160))
    product_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    order_type: Mapped[OrderType] = mapped_column(
        Enum(OrderType), default=OrderType.product_order, index=True
    )
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    quantity_unit: Mapped[str] = mapped_column(String(40), default="item")
    fulfillment_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    fulfillment_status: Mapped[str] = mapped_column(String(80), default="pending_handover")
    handover_otp_hash: Mapped[str | None] = mapped_column(String(128), nullable=True)
    handover_otp_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    handover_verified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    receiver_confirmed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    status: Mapped[OrderStatus] = mapped_column(
        Enum(OrderStatus), default=OrderStatus.pending, index=True
    )
    notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    price: Mapped[float] = mapped_column(Float, default=0)
    accepted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    rejected_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    owner: Mapped[User] = relationship(back_populates="orders")


class OrderRequest(Base):
    __tablename__ = "order_requests"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    request_type: Mapped[RequestType] = mapped_column(Enum(RequestType), index=True)
    sender_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    receiver_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    order_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    product_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    batch_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    quantity: Mapped[int] = mapped_column(Integer)
    quantity_unit: Mapped[str] = mapped_column(String(40), default="item")
    notes: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    status: Mapped[RequestStatus] = mapped_column(
        Enum(RequestStatus), default=RequestStatus.pending, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    responded_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    sender: Mapped[User] = relationship(foreign_keys=[sender_id])
    receiver: Mapped[User] = relationship(foreign_keys=[receiver_id])


class CustomOrderRequest(Base):
    __tablename__ = "custom_order_requests"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    customer_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    target_type: Mapped[CustomRequestTargetType] = mapped_column(
        Enum(CustomRequestTargetType), default=CustomRequestTargetType.specific_artisan
    )
    target_artisan_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id"), index=True, nullable=True
    )
    accepted_by_artisan_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id"), index=True, nullable=True
    )
    order_id: Mapped[str | None] = mapped_column(String(36), index=True, nullable=True)
    title: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(String(1000))
    quantity: Mapped[int] = mapped_column(Integer)
    budget: Mapped[float | None] = mapped_column(Float, nullable=True)
    deadline: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    rejected_artisan_ids: Mapped[str] = mapped_column(String(2000), default="")
    status: Mapped[CustomRequestStatus] = mapped_column(
        Enum(CustomRequestStatus), default=CustomRequestStatus.open, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    responded_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    customer: Mapped[User] = relationship(foreign_keys=[customer_id])
    target_artisan: Mapped[User] = relationship(foreign_keys=[target_artisan_id])
    accepted_by_artisan: Mapped[User | None] = relationship(
        foreign_keys=[accepted_by_artisan_id]
    )


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    type: Mapped[NotificationType] = mapped_column(Enum(NotificationType), index=True)
    title: Mapped[str] = mapped_column(String(160))
    body: Mapped[str] = mapped_column(String(500))
    entity_type: Mapped[str] = mapped_column(String(80))
    entity_id: Mapped[str] = mapped_column(String(36))
    navigation_target: Mapped[str] = mapped_column(String(160))
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    user: Mapped[User] = relationship()
