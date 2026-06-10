import logging
from time import monotonic

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import (
    create_access_token,
    hash_password,
    verify_password,
)
from app.deps import get_current_user
from app.models import User
from app.schemas import (
    LoginRequest,
    SignupRequest,
    TokenResponse,
    UserPublic,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])

MAX_FAILED_LOGIN_ATTEMPTS = 5
FAILED_LOGIN_WINDOW_SECONDS = 15 * 60
_login_attempts: dict[str, list[float]] = {}


def _login_rate_limit_key(request: Request, email: str) -> str:
    client_host = request.client.host if request.client else "unknown"
    return f"{client_host}:{email}"


def _recent_failed_attempts(key: str) -> list[float]:
    now = monotonic()
    attempts = [
        timestamp
        for timestamp in _login_attempts.get(key, [])
        if now - timestamp < FAILED_LOGIN_WINDOW_SECONDS
    ]
    _login_attempts[key] = attempts
    return attempts


def _ensure_login_not_rate_limited(key: str) -> None:
    if len(_recent_failed_attempts(key)) >= MAX_FAILED_LOGIN_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many failed login attempts. Please try again later.",
        )


def _record_failed_login(key: str) -> None:
    attempts = _recent_failed_attempts(key)
    attempts.append(monotonic())
    _login_attempts[key] = attempts


def _clear_failed_login_attempts(key: str) -> None:
    _login_attempts.pop(key, None)


@router.post(
    "/signup",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def signup(
    payload: SignupRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    email = payload.email.strip().lower()
    name = payload.name.strip()

    # Basic validation
    if len(name) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Name must contain at least 2 characters",
        )

    if len(payload.password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 8 characters long",
        )

    existing = db.scalar(
        select(User).where(User.email == email)
    )

    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email is already registered",
        )

    user = User(
        email=email,
        name=name,
        role=payload.role,
        password_hash=hash_password(payload.password),
    )

    db.add(user)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email is already registered",
        )

    db.refresh(user)

    logger.info(
        "New user registered: user_id=%s role=%s",
        user.id,
        user.role.value,
    )

    token = create_access_token(
        subject=user.id,
        role=user.role.value,
    )

    return TokenResponse(
        access_token=token,
        user=user,
    )


@router.post(
    "/login",
    response_model=TokenResponse,
)
def login(
    payload: LoginRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> TokenResponse:
    email = payload.email.strip().lower()
    rate_limit_key = _login_rate_limit_key(request, email)
    _ensure_login_not_rate_limited(rate_limit_key)

    user = db.scalar(
        select(User).where(User.email == email)
    )

    if user is None or not verify_password(
        payload.password,
        user.password_hash,
    ):
        logger.warning(
            "Failed login attempt for email=%s",
            email,
        )
        _record_failed_login(rate_limit_key)

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    logger.info(
        "User logged in: user_id=%s",
        user.id,
    )
    _clear_failed_login_attempts(rate_limit_key)

    token = create_access_token(
        subject=user.id,
        role=user.role.value,
    )

    return TokenResponse(
        access_token=token,
        user=user,
    )


@router.post("/logout")
def logout() -> dict[str, str]:
    # JWT is stateless.
    # Client should remove the token locally.
    return {
        "message": "Logged out"
    }


@router.get(
    "/me",
    response_model=UserPublic,
)
def current_user(
    user: User = Depends(get_current_user),
) -> User:
    return user
