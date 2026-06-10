from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import (
    Base,
    engine,
    ensure_batch_columns,
    ensure_custom_order_request_columns,
    ensure_order_columns,
    ensure_project_columns,
)
from app.routers import (
    auth,
    batches,
    custom_order_requests,
    notifications,
    order_requests,
    orders,
    projects,
    users,
)

app = FastAPI(title="BambooTrace API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=settings.allowed_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup() -> None:
    Base.metadata.create_all(bind=engine)
    ensure_order_columns()
    ensure_project_columns()
    ensure_batch_columns()
    ensure_custom_order_request_columns()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "OK", "message": "BambooTrace API is running"}


app.include_router(auth.router)
app.include_router(batches.router)
app.include_router(projects.router)
app.include_router(orders.router)
app.include_router(order_requests.router)
app.include_router(custom_order_requests.router)
app.include_router(notifications.router)
app.include_router(users.router)
