"""
Router Tracking (PUBLIC — tanpa auth).
FR-PLG-01: Zero-Onboarding Tracking via URL token.
FR-PLG-02: Itemized Invoice & Progress.
FR-PLG-03: Live Queue Tracking.
+ Menampilkan status pembatalan jika is_cancelled=TRUE.
"""

from datetime import date as date_type

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from exceptions import BusinessRuleError
from models import Customer, Order
from schemas import OrderItemOut, TrackingResponse
from services.order_service import (
    STATUS_PROGRESS_MAP,
    generate_tracking_code,
    get_order_with_items,
    get_queue_ahead,
    get_queue_position,
)

router = APIRouter(prefix="/api/track", tags=["Pelacakan Publik"])


@router.get("/{tracking_code}", response_model=TrackingResponse)
async def track(tracking_code: str, db: AsyncSession = Depends(get_db)):
    parts = tracking_code.split("-")
    if len(parts) != 3 or parts[0] != "LND":
        raise BusinessRuleError(
            "Format tracking code tidak valid. Contoh: LND-2906-001", status_code=400
        )
    try:
        queue_number = int(parts[2])
        day, month = int(parts[1][:2]), int(parts[1][2:])
    except (ValueError, IndexError):
        raise BusinessRuleError("Format tracking code tidak valid.", status_code=400)

    today = date_type.today()
    order = None
    for year in [today.year, today.year - 1]:
        try:
            search_date = date_type(year, month, day)
        except ValueError:
            continue
        order = (
            await db.execute(
                select(Order).where(
                    Order.queue_number == queue_number,
                    func.date(Order.order_date) == search_date,
                )
            )
        ).scalar_one_or_none()
        if order:
            break

    if not order:
        raise BusinessRuleError("Pesanan tidak ditemukan.", status_code=404)

    order = await get_order_with_items(order.order_id, db)

    customer_name = "Tidak diketahui"
    if order.customer_id:
        name = (
            await db.execute(
                select(Customer.name).where(Customer.customer_id == order.customer_id)
            )
        ).scalar_one_or_none()
        if name:
            customer_name = name

    if order.is_cancelled:
        return TrackingResponse(
            tracking_code=tracking_code,
            customer_name=customer_name,
            current_status="Dibatalkan",
            status_progress=-1,
            is_cancelled=True,
            queue_position=None,
            queue_ahead=0,
            items=[OrderItemOut.model_validate(i) for i in order.items],
            subtotal=order.subtotal,
            discount=order.discount,
            tax=order.tax,
            grand_total=order.grand_total,
            order_date=order.order_date,
        )

    return TrackingResponse(
        tracking_code=tracking_code,
        customer_name=customer_name,
        current_status=order.current_status,
        status_progress=STATUS_PROGRESS_MAP.get(order.current_status, 0),
        is_cancelled=False,
        queue_position=await get_queue_position(order.order_id, db),
        queue_ahead=await get_queue_ahead(order.order_id, db),
        items=[OrderItemOut.model_validate(i) for i in order.items],
        subtotal=order.subtotal,
        discount=order.discount,
        tax=order.tax,
        grand_total=order.grand_total,
        order_date=order.order_date,
    )
