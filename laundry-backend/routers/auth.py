"""
Router Autentikasi: login, register (owner only), get current user.
"""

from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from jose import jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from database import get_db
from dependencies import get_current_user, require_owner
from exceptions import BusinessRuleError
from models import User
from schemas import LoginRequest, RegisterRequest, TokenResponse, UserOut

router = APIRouter(prefix="/api/auth", tags=["Autentikasi"])
pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
settings = get_settings()


def _create_token(user_id: int, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_EXPIRE_MINUTES)
    return jwt.encode(
        {"sub": str(user_id), "role": role, "exp": expire},
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    user = (
        await db.execute(select(User).where(User.username == body.username))
    ).scalar_one_or_none()

    if not user or not pwd.verify(body.password, user.password_hash):
        raise BusinessRuleError("Username atau password salah.", status_code=401)

    return TokenResponse(
        access_token=_create_token(user.user_id, user.role),
        role=user.role,
        user_id=user.user_id,
    )


@router.post("/register", response_model=UserOut, status_code=201)
async def register(
    body: RegisterRequest,
    db: AsyncSession = Depends(get_db),
    _owner: User = Depends(require_owner),
):
    if (
        await db.execute(select(User).where(User.username == body.username))
    ).scalar_one_or_none():
        raise BusinessRuleError(
            f"Username '{body.username}' sudah terdaftar.", status_code=409
        )

    user = User(
        username=body.username,
        password_hash=pwd.hash(body.password),
        role=body.role,
    )
    db.add(user)
    await db.flush()
    return user


@router.get("/me", response_model=UserOut)
async def me(current_user: User = Depends(get_current_user)):
    return current_user
