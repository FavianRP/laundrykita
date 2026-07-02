"""
Business logic untuk modul Order.
Menangani: FR-KSR-01 (Multi-Item Drop), FR-KSR-02 (Auto Upsert),
FR-KSR-03 (Hard Lock), FR-PLG-03 (Queue Tracking).
+ Soft cancel: order yang is_cancelled=TRUE di-exclude dari antrean.
"""

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from config import get_settings
from exceptions import BusinessRuleError
from guards import enforce_order_immutability
from models import Customer, Order, OrderItem

settings = get_settings()

# Mapping status produksi → persentase progres (0-100)
STATUS_PROGRESS_MAP = {
    "Antrean": 0,
    "Dicuci": 25,
    "Disetrika": 50,
    "Siap Diambil": 75,
    "Selesai": 100,
}


def generate_customer_id() -> str:
    """Generate ID pelanggan unik: CUS-XXXXXXXX"""
    return f"CUS-{uuid.uuid4().hex[:8].upper()}"


def generate_tracking_code(queue_number: int, order_date: datetime) -> str:
    """
    Derive tracking code dari queue_number + tanggal.
    Format: LND-DDMM-NNN (contoh: LND-2906-001)
    """
    return f"LND-{order_date.strftime('%d%m')}-{queue_number:03d}"


def calculate_item_subtotal(weight_quantity: Decimal, price_per_unit: int) -> int:
    return int(weight_quantity * price_per_unit)


def calculate_order_totals(
    items_subtotals: list[int],
    discount: int = 0,
    tax_rate: float = 0.0,
) -> dict:
    subtotal = sum(items_subtotals)
    taxable_base = max(0, subtotal - discount)
    tax = int(round(taxable_base * tax_rate / 100))
    grand_total = subtotal - discount + tax
    return {
        "subtotal": subtotal,
        "discount": discount,
        "tax": tax,
        "grand_total": grand_total,
    }


async def get_or_create_customer(name: str, phone: str, db: AsyncSession) -> Customer:
    """
    FR-KSR-02: Automated Upsert Profil.
    Deteksi nomor telepon → buat baru atau link ke existing.
    """
    result = await db.execute(select(Customer).where(Customer.phone_number == phone))
    customer = result.scalar_one_or_none()

    if customer is None:
        customer = Customer(
            customer_id=generate_customer_id(),
            name=name,
            phone_number=phone,
        )
        db.add(customer)
        await db.flush()
    elif customer.name != name:
        customer.name = name
        await db.flush()

    return customer


async def generate_queue_number(db: AsyncSession) -> int:
    """
    Generate nomor antrean harian berurutan.
    Hanya menghitung order yang TIDAK dibatalkan.
    """
    today = date.today()
    result = await db.execute(
        select(func.coalesce(func.max(Order.queue_number), 0)).where(
            and_(
                func.date(Order.order_date) == today,
                Order.is_cancelled == False,  # noqa: E712 — SQLAlchemy requires == for filter
            )
        )
    )
    max_queue = result.scalar_one()
    return int(max_queue) + 1


async def create_order(
    data,
    requested_by_id: int,
    db: AsyncSession,
) -> Order:
    """
    FR-KSR-01 + FR-KSR-02 + FR-KSR-03.
    """
    customer = await get_or_create_customer(data.customer_name, data.customer_phone, db)
    queue_number = await generate_queue_number(db)

    order_items_data = []
    for item in data.items:
        item_sub = calculate_item_subtotal(item.weight_quantity, item.price_per_unit)
        order_items_data.append(
            {
                "service_type": item.service_type,
                "weight_quantity": item.weight_quantity,
                "price_per_unit": item.price_per_unit,
                "item_subtotal": item_sub,
            }
        )

    tax_rate = data.tax_rate if data.tax_rate is not None else settings.TAX_RATE_DEFAULT
    totals = calculate_order_totals(
        [d["item_subtotal"] for d in order_items_data],
        data.discount,
        tax_rate,
    )

    order = Order(
        customer_id=customer.customer_id,
        queue_number=queue_number,
        payment_status="Belum Lunas",
        current_status="Antrean",
        is_locked=True,
        is_cancelled=False,
        **totals,
    )
    db.add(order)
    await db.flush()

    for item_data in order_items_data:
        oi = OrderItem(order_id=order.order_id, **item_data)
        db.add(oi)

    await db.flush()
    return order


async def update_production_status(
    order_id: int,
    new_status: str,
    db: AsyncSession,
) -> Order:
    """
    Kasir memperbarui status produksi harian.
    Bukan perubahan data finansial → diizinkan meski terkunci.
    """
    result = await db.execute(select(Order).where(Order.order_id == order_id))
    order = result.scalar_one_or_none()

    if not order:
        raise BusinessRuleError(f"Order #{order_id} tidak ditemukan.", status_code=404)

    if order.is_cancelled:
        raise BusinessRuleError(
            f"Tidak dapat mengubah status produksi. Order #{order_id} sudah dibatalkan."
        )

    current_prog = STATUS_PROGRESS_MAP.get(order.current_status, 0)
    new_prog = STATUS_PROGRESS_MAP.get(new_status, 0)

    if new_prog < current_prog:
        raise BusinessRuleError(
            f"Status produksi tidak boleh mundur "
            f"dari '{order.current_status}' ke '{new_status}'."
        )

    order.current_status = new_status
    await db.flush()
    return order
    return order


async def get_order_with_items(order_id: int, db: AsyncSession) -> Order | None:
    """Load order beserta semua item-nya."""
    result = await db.execute(
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.order_id == order_id)
    )
    return result.scalar_one_or_none()


async def list_orders(
    db: AsyncSession,
    payment_status: str | None = None,
    current_status: str | None = None,
    customer_id: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    include_cancelled: bool = False,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[Order], int]:
    """List orders dengan filter & pagination. Default exclude cancelled."""
    query = select(Order)
    count_query = select(func.count()).select_from(Order)
    conditions = []

    if payment_status:
        conditions.append(Order.payment_status == payment_status)
    if current_status:
        conditions.append(Order.current_status == current_status)
    if customer_id:
        conditions.append(Order.customer_id == customer_id)
    if date_from:
        conditions.append(func.date(Order.order_date) >= date_from)
    if date_to:
        conditions.append(func.date(Order.order_date) <= date_to)
    if not include_cancelled:
        conditions.append(Order.is_cancelled == False)  # noqa: E712

    if conditions:
        clause = and_(*conditions)
        query = query.where(clause)
        count_query = count_query.where(clause)

    total = (await db.execute(count_query)).scalar_one()
    offset = (page - 1) * page_size
    query = query.order_by(Order.order_id.desc()).offset(offset).limit(page_size)
    orders = list((await db.execute(query)).scalars().all())

    return orders, total


async def get_queue_position(order_id: int, db: AsyncSession) -> int | None:
    """
    FR-PLG-03: Posisi antrean relatif (1-based).
    Exclude order yang sudah dibatalkan dari hitungan.
    Return None jika bukan di fase Antrean.
    """
    order = (
        await db.execute(select(Order).where(Order.order_id == order_id))
    ).scalar_one_or_none()
    if not order or order.current_status != "Antrean" or order.is_cancelled:
        return None

    today = date.today()
    ahead = (
        await db.execute(
            select(func.count())
            .select_from(Order)
            .where(
                and_(
                    func.date(Order.order_date) == today,
                    Order.current_status == "Antrean",
                    Order.is_cancelled == False,  # noqa: E712
                    Order.queue_number < order.queue_number,
                )
            )
        )
    ).scalar_one()

    return int(ahead) + 1


async def get_queue_ahead(order_id: int, db: AsyncSession) -> int:
    """Jumlah pesanan di depan dalam antrean hari ini. Exclude cancelled."""
    order = (
        await db.execute(select(Order).where(Order.order_id == order_id))
    ).scalar_one_or_none()
    if not order or order.current_status != "Antrean" or order.is_cancelled:
        return 0

    today = date.today()
    result = await db.execute(
        select(func.count())
        .select_from(Order)
        .where(
            and_(
                func.date(Order.order_date) == today,
                Order.current_status == "Antrean",
                Order.is_cancelled == False,  # noqa: E712
                Order.queue_number < order.queue_number,
            )
        )
    )
    return int(result.scalar_one())


async def update_payment_status(
    order_id: int,
    new_status: str,
    db: AsyncSession,
) -> Order:
    """
    Update status pembayaran.
    Diizinkan langsung karena tidak mengubah kalkulasi finansial.
    Ditolak jika order sudah dibatalkan.
    """
    result = await db.execute(select(Order).where(Order.order_id == order_id))
    order = result.scalar_one_or_none()

    if not order:
        raise BusinessRuleError(f"Order #{order_id} tidak ditemukan.", status_code=404)

    if order.is_cancelled:
        raise BusinessRuleError(
            "Tidak dapat mengubah status pembayaran. "
            f"Order #{order_id} sudah dibatalkan."
        )

    order.payment_status = new_status
    await db.flush()
    return order
