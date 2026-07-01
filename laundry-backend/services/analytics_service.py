"""
Business logic untuk modul Analytics.
FR-OWN-03: Financial Analytics Engine.
Order yang is_cancelled=TRUE di-exclude dari seluruh metrik.
"""

from datetime import date
from decimal import Decimal

from models import Order, OrderItem
from schemas import (
    FinancialAnalyticsResponse,
    FinancialSummary,
    ServiceBreakdown,
    ServiceBreakdownResponse,
)
from sqlalchemy import String, and_, case, cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession


async def get_financial_analytics(
    db: AsyncSession,
    date_from: date,
    date_to: date,
    group_by: str = "day",
) -> FinancialAnalyticsResponse:
    base_cond = and_(
        func.date(Order.order_date) >= date_from,
        func.date(Order.order_date) <= date_to,
        Order.is_cancelled == False,  # noqa: E712
    )

    if group_by == "month":
        date_expr = func.date_format(Order.order_date, "%Y-%m")
    elif group_by == "week":
        date_expr = func.date_format(Order.order_date, "%x-W%v")
    else:
        date_expr = func.date_format(Order.order_date, "%Y-%m-%d")

    grouped = (
        select(
            date_expr.label("period"),
            func.count(Order.order_id).label("total_orders"),
            func.coalesce(func.sum(Order.subtotal), 0).label("total_subtotal"),
            func.coalesce(func.sum(Order.discount), 0).label("total_discount"),
            func.coalesce(func.sum(Order.tax), 0).label("total_tax"),
            func.coalesce(func.sum(Order.grand_total), 0).label("total_grand_total"),
            func.coalesce(
                func.sum(
                    case((Order.payment_status == "Lunas", Order.grand_total), else_=0)
                ),
                0,
            ).label("total_paid"),
            func.coalesce(
                func.sum(
                    case(
                        (Order.payment_status == "Belum Lunas", Order.grand_total),
                        else_=0,
                    )
                ),
                0,
            ).label("total_unpaid"),
        )
        .where(base_cond)
        .group_by(date_expr)
        .order_by(date_expr)
    )

    rows = (await db.execute(grouped)).all()
    summaries = [
        FinancialSummary(
            period_label=str(r.period),
            total_orders=r.total_orders,
            total_subtotal=int(r.total_subtotal),
            total_discount=int(r.total_discount),
            total_tax=int(r.total_tax),
            total_grand_total=int(r.total_grand_total),
            total_paid=int(r.total_paid),
            total_unpaid=int(r.total_unpaid),
            avg_grand_total=int(r.total_grand_total // r.total_orders)
            if r.total_orders
            else 0,
        )
        for r in rows
    ]

    ov = (
        await db.execute(
            select(
                func.count(Order.order_id).label("total_orders"),
                func.coalesce(func.sum(Order.subtotal), 0).label("total_subtotal"),
                func.coalesce(func.sum(Order.discount), 0).label("total_discount"),
                func.coalesce(func.sum(Order.tax), 0).label("total_tax"),
                func.coalesce(func.sum(Order.grand_total), 0).label(
                    "total_grand_total"
                ),
                func.coalesce(
                    func.sum(
                        case(
                            (Order.payment_status == "Lunas", Order.grand_total),
                            else_=0,
                        )
                    ),
                    0,
                ).label("total_paid"),
                func.coalesce(
                    func.sum(
                        case(
                            (Order.payment_status == "Belum Lunas", Order.grand_total),
                            else_=0,
                        )
                    ),
                    0,
                ).label("total_unpaid"),
            ).where(base_cond)
        )
    ).one()

    overall = FinancialSummary(
        period_label="Keseluruhan",
        total_orders=ov.total_orders,
        total_subtotal=int(ov.total_subtotal),
        total_discount=int(ov.total_discount),
        total_tax=int(ov.total_tax),
        total_grand_total=int(ov.total_grand_total),
        total_paid=int(ov.total_paid),
        total_unpaid=int(ov.total_unpaid),
        avg_grand_total=int(ov.total_grand_total // ov.total_orders)
        if ov.total_orders
        else 0,
    )

    return FinancialAnalyticsResponse(summaries=summaries, overall=overall)


async def get_service_breakdown(
    db: AsyncSession,
    date_from: date,
    date_to: date,
) -> ServiceBreakdownResponse:
    rows = (
        await db.execute(
            select(
                OrderItem.service_type,
                func.count(OrderItem.item_id).label("total_items"),
                func.coalesce(func.sum(OrderItem.weight_quantity), 0).label(
                    "total_weight"
                ),
                func.coalesce(func.sum(OrderItem.item_subtotal), 0).label(
                    "total_revenue"
                ),
            )
            .join(Order, OrderItem.order_id == Order.order_id)
            .where(
                and_(
                    func.date(Order.order_date) >= date_from,
                    func.date(Order.order_date) <= date_to,
                    Order.is_cancelled == False,  # noqa: E712
                )
            )
            .group_by(OrderItem.service_type)
            .order_by(func.sum(OrderItem.item_subtotal).desc())
        )
    ).all()

    return ServiceBreakdownResponse(
        breakdown=[
            ServiceBreakdown(
                service_type=r.service_type,
                total_items=r.total_items,
                total_weight_quantity=Decimal(str(r.total_weight)),
                total_revenue=int(r.total_revenue),
            )
            for r in rows
        ]
    )
