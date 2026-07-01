"""
Business logic untuk modul Edit Request, Approval & Cancel.
FR-KSR-04 (Granular Edit Request)
FR-OWN-01 (Git-Diff View)
FR-OWN-02 (Atomic Level Approval)
+ Soft Cancel via Edit Request
"""

from decimal import Decimal

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from exceptions import BusinessRuleError
from guards import ImmutabilityBypass, enforce_order_immutability
from models import EditRequest, EditRequestItem, Order, OrderItem
from services.order_service import calculate_item_subtotal, calculate_order_totals


async def create_edit_request(
    data,  # EditRequestCreate schema
    requested_by: int,
    db: AsyncSession,
) -> EditRequest:
    """
    FR-KSR-04: Granular Edit Request.
    Ditolak jika order sudah dibatalkan atau belum terkunci.
    """
    result = await db.execute(select(Order).where(Order.order_id == data.order_id))
    order = result.scalar_one_or_none()

    if not order:
        raise BusinessRuleError(
            f"Order #{data.order_id} tidak ditemukan.", status_code=404
        )

    if order.is_cancelled:
        raise BusinessRuleError(
            "Tidak dapat mengajukan Edit Request. "
            f"Order #{data.order_id} sudah dibatalkan."
        )
    if not order.is_locked:
        raise BusinessRuleError("Edit Request hanya untuk order yang sudah terkunci.")

    pending = (
        await db.execute(
            select(EditRequest).where(
                and_(
                    EditRequest.order_id == data.order_id,
                    EditRequest.approval_status == "Pending",
                )
            )
        )
    ).scalar_one_or_none()
    if pending:
        raise BusinessRuleError(
            "Sudah ada Edit Request Pending untuk order ini. "
            "Tunggu hingga diproses Owner."
        )

    existing_items = {
        i.item_id: i
        for i in (
            await db.execute(
                select(OrderItem).where(OrderItem.order_id == data.order_id)
            )
        )
        .scalars()
        .all()
    }

    er = EditRequest(
        order_id=data.order_id,
        requested_by=requested_by,
        reason=data.reason,
        approval_status="Pending",
        is_cancellation_request=False,
    )
    db.add(er)
    await db.flush()

    for item_data in data.items:
        old_wq = old_ppu = old_sub = None

        if item_data.order_item_id is not None:
            existing = existing_items.get(item_data.order_item_id)
            if existing is None:
                raise BusinessRuleError(
                    f"Order item ID {item_data.order_item_id} tidak ditemukan "
                    f"pada order #{data.order_id}."
                )
            old_wq = existing.weight_quantity
            old_ppu = existing.price_per_unit
            old_sub = existing.item_subtotal

        new_sub = None
        if (
            item_data.new_weight_quantity is not None
            and item_data.new_price_per_unit is not None
        ):
            new_sub = calculate_item_subtotal(
                item_data.new_weight_quantity, item_data.new_price_per_unit
            )

        db.add(
            EditRequestItem(
                request_id=er.request_id,
                order_item_id=item_data.order_item_id,
                service_type=item_data.service_type,
                old_weight_quantity=old_wq,
                new_weight_quantity=item_data.new_weight_quantity,
                old_price_per_unit=old_ppu,
                new_price_per_unit=item_data.new_price_per_unit,
                old_item_subtotal=old_sub,
                new_item_subtotal=new_sub,
            )
        )

    await db.flush()
    return er


async def create_cancel_request(
    data,  # CancelOrderRequest schema
    requested_by: int,
    db: AsyncSession,
) -> EditRequest:
    """
    Soft Cancel: kasir mengajukan pembatalan order.
    - Tidak ada edit_request_items (tidak ada perubahan item)
    - Flag is_cancellation_request = TRUE
    - Owner approve → is_cancelled = TRUE
    """
    result = await db.execute(select(Order).where(Order.order_id == data.order_id))
    order = result.scalar_one_or_none()

    if not order:
        raise BusinessRuleError(
            f"Order #{data.order_id} tidak ditemukan.", status_code=404
        )

    if order.is_cancelled:
        raise BusinessRuleError(f"Order #{data.order_id} sudah dibatalkan sebelumnya.")
    if not order.is_locked:
        raise BusinessRuleError("Pembatalan hanya untuk order yang sudah terkunci.")

    # Cek pending request apapun (edit atau cancel)
    pending = (
        await db.execute(
            select(EditRequest).where(
                and_(
                    EditRequest.order_id == data.order_id,
                    EditRequest.approval_status == "Pending",
                )
            )
        )
    ).scalar_one_or_none()
    if pending:
        kind = "pembatalan" if pending.is_cancellation_request else "perbaikan data"
        raise BusinessRuleError(
            f"Sudah ada pengajuan {kind} Pending untuk order ini. "
            "Tunggu hingga diproses Owner."
        )

    er = EditRequest(
        order_id=data.order_id,
        requested_by=requested_by,
        reason=data.reason,
        approval_status="Pending",
        is_cancellation_request=True,
    )
    db.add(er)
    await db.flush()
    return er


async def approve_edit_request(
    request_id: int,
    approved_by: int,
    db: AsyncSession,
) -> EditRequest:
    """
    FR-OWN-02: Atomic Level Approval.
    Menangani 2 jalur:
    - is_cancellation_request=FALSE → update items + rekalkulasi (logika lama)
    - is_cancellation_request=TRUE  → set is_cancelled=TRUE
    Keduanya dalam konteks ImmutabilityBypass (All-or-Nothing).
    """
    er = (
        await db.execute(
            select(EditRequest).where(EditRequest.request_id == request_id)
        )
    ).scalar_one_or_none()
    if not er:
        raise BusinessRuleError(
            f"Edit Request #{request_id} tidak ditemukan.", status_code=404
        )
    if er.approval_status != "Pending":
        raise BusinessRuleError(f"Edit Request sudah '{er.approval_status}'.")

    order = (
        await db.execute(select(Order).where(Order.order_id == er.order_id))
    ).scalar_one_or_none()
    if not order:
        raise BusinessRuleError("Order terkait tidak ditemukan.", status_code=404)

    if order.is_cancelled:
        raise BusinessRuleError("Order sudah dibatalkan sebelumnya.")

    with ImmutabilityBypass():
        if er.is_cancellation_request:
            # =============================================
            #  JALUR PEMBATALAN
            # =============================================
            order.is_locked = False
            await db.flush()

            order.is_cancelled = True
            order.is_locked = True

            er.approval_status = "Approved"
            er.approved_by = approved_by
            await db.flush()

        else:
            # =============================================
            #  JALUR EDIT ITEM (logika sebelumnya)
            # =============================================
            eri_list = list(
                (
                    await db.execute(
                        select(EditRequestItem).where(
                            EditRequestItem.request_id == request_id
                        )
                    )
                )
                .scalars()
                .all()
            )

            existing_items = {
                i.item_id: i
                for i in (
                    await db.execute(
                        select(OrderItem).where(OrderItem.order_id == order.order_id)
                    )
                )
                .scalars()
                .all()
            }

            if order.subtotal > order.discount:
                taxable = order.subtotal - order.discount
                existing_tax_rate = (order.tax / taxable) * 100 if taxable > 0 else 0.0
            else:
                existing_tax_rate = 0.0

            order.is_locked = False
            await db.flush()

            items_to_remove: set[int] = set()

            for eri in eri_list:
                if eri.order_item_id is not None:
                    existing = existing_items.get(eri.order_item_id)
                    if existing is None:
                        continue

                    if (
                        eri.new_weight_quantity is not None
                        and eri.new_weight_quantity > 0
                    ):
                        existing.service_type = eri.service_type
                        existing.weight_quantity = eri.new_weight_quantity
                        if eri.new_price_per_unit is not None:
                            existing.price_per_unit = eri.new_price_per_unit
                        if eri.new_item_subtotal is not None:
                            existing.item_subtotal = eri.new_item_subtotal
                    else:
                        items_to_remove.add(eri.order_item_id)
                else:
                    if eri.new_weight_quantity and eri.new_weight_quantity > 0:
                        db.add(
                            OrderItem(
                                order_id=order.order_id,
                                service_type=eri.service_type,
                                weight_quantity=eri.new_weight_quantity,
                                price_per_unit=eri.new_price_per_unit or 0,
                                item_subtotal=eri.new_item_subtotal or 0,
                            )
                        )

            for item_id in items_to_remove:
                if item_id in existing_items:
                    await db.delete(existing_items[item_id])

            await db.flush()

            all_items = list(
                (
                    await db.execute(
                        select(OrderItem).where(OrderItem.order_id == order.order_id)
                    )
                )
                .scalars()
                .all()
            )

            subtotals = [i.item_subtotal for i in all_items]
            totals = calculate_order_totals(
                subtotals, order.discount, existing_tax_rate
            )

            order.subtotal = totals["subtotal"]
            order.tax = totals["tax"]
            order.grand_total = totals["grand_total"]
            order.is_locked = True

            er.approval_status = "Approved"
            er.approved_by = approved_by
            await db.flush()

    return er


async def reject_edit_request(
    request_id: int,
    approved_by: int,
    db: AsyncSession,
) -> EditRequest:
    """Tolak edit request atau cancel request."""
    er = (
        await db.execute(
            select(EditRequest).where(EditRequest.request_id == request_id)
        )
    ).scalar_one_or_none()
    if not er:
        raise BusinessRuleError(
            f"Edit Request #{request_id} tidak ditemukan.", status_code=404
        )
    if er.approval_status != "Pending":
        raise BusinessRuleError(f"Edit Request sudah '{er.approval_status}'.")

    er.approval_status = "Rejected"
    er.approved_by = approved_by
    await db.flush()
    return er


async def get_edit_request_detail(
    request_id: int, db: AsyncSession
) -> EditRequest | None:
    """Load edit request beserta semua item komparasinya."""
    er = (
        await db.execute(
            select(EditRequest)
            .options(selectinload(EditRequest.items))
            .where(EditRequest.request_id == request_id)
        )
    ).scalar_one_or_none()
    return er


async def list_edit_requests(
    db: AsyncSession,
    approval_status: str | None = None,
    order_id: int | None = None,
    is_cancellation: bool | None = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[EditRequest], int]:
    query = select(EditRequest)
    count_query = select(func.count()).select_from(EditRequest)
    conditions = []

    if approval_status:
        conditions.append(EditRequest.approval_status == approval_status)
    if order_id:
        conditions.append(EditRequest.order_id == order_id)
    if is_cancellation is not None:
        conditions.append(EditRequest.is_cancellation_request == is_cancellation)

    if conditions:
        clause = and_(*conditions)
        query = query.where(clause)
        count_query = count_query.where(clause)

    total = (await db.execute(count_query)).scalar_one()
    offset = (page - 1) * page_size
    query = (
        query.order_by(EditRequest.created_at.desc()).offset(offset).limit(page_size)
    )
    return list((await db.execute(query)).scalars().all()), total
