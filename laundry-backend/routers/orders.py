"""
Router Orders: CRUD pesanan, update status produksi.
"""

from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import require_any_auth, require_kasir
from exceptions import BusinessRuleError
from models import Customer, Order, OrderItem
from schemas import (
    OrderCreate,
    OrderItemOut,
    OrderListItem,
    OrderOut,
    OrderPaymentUpdate,
    OrderStatusUpdate,
)
from services.order_service import (
    create_order,
    generate_tracking_code,
    get_order_with_items,
    list_orders,
    update_payment_status,
    update_production_status,
)

router = APIRouter(prefix="/api/orders", tags=["Orders"])


def _to_out(order: Order, with_items: bool = False) -> OrderOut:
    return OrderOut(
        order_id=order.order_id,
        tracking_code=generate_tracking_code(order.queue_number, order.order_date),
        customer_id=order.customer_id,
        queue_number=order.queue_number,
        payment_status=order.payment_status,
        current_status=order.current_status,
        subtotal=order.subtotal,
        discount=order.discount,
        tax=order.tax,
        grand_total=order.grand_total,
        is_locked=order.is_locked,
        is_cancelled=order.is_cancelled,
        order_date=order.order_date,
        items=[OrderItemOut.model_validate(i) for i in order.items]
        if with_items and order.items
        else [],
    )


@router.post("", response_model=OrderOut, status_code=201)
async def create(
    body: OrderCreate,
    db: AsyncSession = Depends(get_db),
    user=Depends(require_kasir),
):
    order = await create_order(body, user.user_id, db)
    order = await get_order_with_items(order.order_id, db)
    return _to_out(order, with_items=True)


@router.get("")
async def index(
    payment_status: str | None = Query(None),
    current_status: str | None = Query(None),
    customer_id: str | None = None,
    date_from: date | None = Query(None),
    date_to: date | None = Query(None),
    include_cancelled: bool = Query(
        False, description="Sertakan order yang sudah dibatalkan"
    ),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    _user=Depends(require_any_auth),
):
    orders, total = await list_orders(
        db,
        payment_status,
        current_status,
        customer_id,
        date_from,
        date_to,
        include_cancelled,
        page,
        page_size,
    )
    if not orders:
        return {
            "data": [],
            "pagination": {
                "page": 1,
                "page_size": page_size,
                "total": 0,
                "total_pages": 0,
            },
        }

    cids = [o.customer_id for o in orders if o.customer_id]
    cmap = {}
    if cids:
        cmap = {
            r.customer_id: r.name
            for r in (
                await db.execute(
                    select(Customer.customer_id, Customer.name).where(
                        Customer.customer_id.in_(cids)
                    )
                )
            ).all()
        }

    oids = [o.order_id for o in orders]
    icmap = {
        r.order_id: r[1]
        for r in (
            await db.execute(
                select(OrderItem.order_id, func.count(OrderItem.item_id))
                .where(OrderItem.order_id.in_(oids))
                .group_by(OrderItem.order_id)
            )
        ).all()
    }

    data = [
        OrderListItem(
            order_id=o.order_id,
            tracking_code=generate_tracking_code(o.queue_number, o.order_date),
            customer_name=cmap.get(o.customer_id),
            queue_number=o.queue_number,
            payment_status=o.payment_status,
            current_status=o.current_status,
            grand_total=o.grand_total,
            is_locked=o.is_locked,
            is_cancelled=o.is_cancelled,
            order_date=o.order_date,
            item_count=icmap.get(o.order_id, 0),
        ).model_dump()
        for o in orders
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


@router.get("/{order_id}", response_model=OrderOut)
async def show(
    order_id: int, db: AsyncSession = Depends(get_db), _user=Depends(require_any_auth)
):
    order = await get_order_with_items(order_id, db)
    if not order:
        raise BusinessRuleError(f"Order #{order_id} tidak ditemukan.", status_code=404)
    return _to_out(order, with_items=True)


@router.patch("/{order_id}/status", response_model=OrderOut)
async def update_status(
    order_id: int,
    body: OrderStatusUpdate,
    db: AsyncSession = Depends(get_db),
    _user=Depends(require_kasir),
):
    order = await update_production_status(order_id, body.current_status, db)
    order = await get_order_with_items(order.order_id, db)
    return _to_out(order, with_items=True)


@router.patch("/{order_id}/payment", response_model=OrderOut)
async def update_payment(
    order_id: int,
    body: OrderPaymentUpdate,
    db: AsyncSession = Depends(get_db),
    _user=Depends(require_kasir),
):
    order = await update_payment_status(order_id, body.payment_status, db)
    order = await get_order_with_items(order.order_id, db)
    return _to_out(order, with_items=True)
