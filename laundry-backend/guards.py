import contextvars

from fastapi import HTTPException, status
from models import Order
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# ContextVar: per-request isolation, thread-safe & async-safe
_bypass_flag: contextvars.ContextVar[bool] = contextvars.ContextVar(
    "_bypass_immutability", default=False
)


class ImmutabilityBypass:
    """
    Context manager untuk menonaktifkan sementara pengecekan immutability.
    HANYA boleh digunakan di dalam atomic approval flow owner.
    """

    def __enter__(self):
        _bypass_flag.set(True)
        return self

    def __exit__(self, *exc):
        _bypass_flag.set(False)
        return False


async def enforce_order_immutability(order_id: int, db: AsyncSession) -> Order:
    """
    Cek apakah order terkunci. Return objek Order jika lolos.
    Lempar 403 jika terkunci dan tidak dalam konteks bypass.
    Lempar 404 jika order tidak ditemukan.
    """
    result = await db.execute(select(Order).where(Order.order_id == order_id))
    order = result.scalar_one_or_none()

    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Order dengan ID {order_id} tidak ditemukan.",
        )

    if order.is_locked and not _bypass_flag.get():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                f"Order #{order_id} dalam status TERKUNCI (is_locked=TRUE). "
                "Semua perubahan data wajib melalui mekanisme Edit Request "
                "dan menunggu persetujuan Owner."
            ),
        )

    return order
