from pathlib import Path
import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.core.database import (
    Base,
    engine,
    ensure_batch_columns,
    ensure_custom_order_request_columns,
    ensure_order_columns,
    ensure_project_columns,
    ensure_user_columns,
)
from app.routers import (
    auth,
    batches,
    custom_order_requests,
    dashboard,
    notifications,
    order_requests,
    orders,
    projects,
    uploads,
    users,
)

app = FastAPI(title="BambooTrace API", version="1.0.0")
logger = logging.getLogger("bambootrace.api")
STATIC_DIR = Path(__file__).resolve().parent.parent / "static"
UPLOAD_DIR = STATIC_DIR / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


@app.on_event("startup")
def on_startup() -> None:
    if not settings.run_db_startup_tasks:
        logger.info("Database startup tasks are disabled")
        return
    Base.metadata.create_all(bind=engine)
    ensure_user_columns()
    ensure_order_columns()
    ensure_project_columns()
    ensure_batch_columns()
    ensure_custom_order_request_columns()


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    errors = [
        {
            "field": ".".join(str(part) for part in error.get("loc", [])),
            "message": error.get("msg", "Invalid value"),
        }
        for error in exc.errors()
    ]
    return JSONResponse(
        status_code=422,
        content={"detail": "Invalid request data", "errors": errors},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled API error")
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Please try again later."},
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "OK", "message": "BambooTrace API is running"}


app.include_router(auth.router)
app.include_router(batches.router)
app.include_router(projects.router)
app.include_router(orders.router)
app.include_router(order_requests.router)
app.include_router(custom_order_requests.router)
app.include_router(dashboard.router)
app.include_router(notifications.router)
app.include_router(users.router)
app.include_router(uploads.router)
app.mount(
    "/static/uploads",
    StaticFiles(directory=str(UPLOAD_DIR), html=False),
    name="uploads",
)



