from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from config import get_settings
from database import get_db
from models import User

settings = get_settings()
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Decode JWT dan return objek User. Throw 401 jika invalid."""
    token = credentials.credentials
    try:
        payload = jwt.decode(
            token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
        )
        user_id_str: str = payload.get("sub")
        role: str = payload.get("role")
        if user_id_str is None or role is None:
            raise HTTPException(
                status_code=401, detail="Token tidak valid — payload kosong."
            )
        user_id = int(user_id_str)
    except JWTError as e:
        raise HTTPException(status_code=401, detail="Token expired atau tidak valid.")

    result = await db.execute(select(User).where(User.user_id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=401, detail="Pengguna tidak ditemukan di database."
        )
    return user


def require_role(*allowed_roles: str):
    """
    Factory: mengembalikan dependency yang mengecek role.
    Penggunaan: Depends(require_role("owner"))
    """

    async def checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=403,
                detail=f"Akses ditolak. Dibutuhkan role: {', '.join(allowed_roles)}.",
            )
        return current_user

    return checker


# Shortcut yang sering dipakai
require_kasir = require_role("kasir", "owner")
require_owner = require_role("owner")
require_any_auth = require_role("kasir", "owner")
