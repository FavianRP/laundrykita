"""
Router Customers: list & detail pelanggan.
Akses: kasir & owner.
"""

from database import get_db
from dependencies import require_any_auth
from fastapi import APIRouter, Depends, HTTPException, Query
from models import Customer, Order
from schemas import CustomerOut
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/api/customers", tags=["Pelanggan"])


@router.get("")
async def index(
    search: str | None = Query(None, description="Cari nama/nomor telepon"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    _user=Depends(require_any_auth),
):
    query = select(Customer)
    count_q = select(func.count()).select_from(Customer)

    if search:
        cond = Customer.name.ilike(f"%{search}%") | Customer.phone_number.ilike(
            f"%{search}%"
        )
        query = query.where(cond)
        count_q = count_q.where(cond)

    total = (await db.execute(count_q)).scalar_one()
    offset = (page - 1) * page_size
    customers = list(
        (
            await db.execute(
                query.order_by(Customer.created_at.desc())
                .offset(offset)
                .limit(page_size)
            )
        )
        .scalars()
        .all()
    )

    # Batch order counts
    cids = [c.customer_id for c in customers]
    oc = {}
    if cids:
        oc = {
            r.customer_id: r[1]
            for r in (
                await db.execute(
                    select(Order.customer_id, func.count(Order.order_id))
                    .where(Order.customer_id.in_(cids))
                    .group_by(Order.customer_id)
                )
            ).all()
        }

    data = [
        {
            **CustomerOut.model_validate(c).model_dump(),
            "total_orders": oc.get(c.customer_id, 0),
        }
        for c in customers
    ]

    return {
        "data": data,
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total": total,
            "total_pages": (total + page_size - 1) // page_size if total else 0,
        },
    }


@router.get("/{customer_id}", response_model=CustomerOut)
async def show(
    customer_id: str,
    db: AsyncSession = Depends(get_db),
    _user=Depends(require_any_auth),
):
    c = (
        await db.execute(select(Customer).where(Customer.customer_id == customer_id))
    ).scalar_one_or_none()
    if not c:
        raise HTTPException(status_code=404, detail="Pelanggan tidak ditemukan.")
    return c
