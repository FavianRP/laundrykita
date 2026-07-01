"""
Pydantic v2 Schemas — semua DTO untuk request/response.
Dipisah per domain: Auth, Customer, Order, EditRequest, Tracking, Analytics.
"""

from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, Field

# ================================================================
# AUTH
# ================================================================


class LoginRequest(BaseModel):
    username: str
    password: str


class RegisterRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6)
    role: str = Field(..., pattern="^(kasir|owner)$")


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user_id: int


class UserOut(BaseModel):
    user_id: int
    username: str
    role: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ================================================================
# CUSTOMER
# ================================================================


class CustomerBrief(BaseModel):
    customer_id: str
    name: str
    phone_number: str

    model_config = {"from_attributes": True}


class CustomerOut(BaseModel):
    customer_id: str
    name: str
    phone_number: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ================================================================
# ORDER ITEM
# ================================================================


class OrderItemCreate(BaseModel):
    service_type: str = Field(..., pattern="^(Kiloan|Sepatu|Boneka|Karpet|Jas)$")
    weight_quantity: Decimal = Field(..., gt=0, decimal_places=2, max_digits=5)
    price_per_unit: int = Field(..., gt=0)


class OrderItemOut(BaseModel):
    item_id: int
    order_id: int
    service_type: str
    weight_quantity: Decimal
    price_per_unit: int
    item_subtotal: int

    model_config = {"from_attributes": True}


# ================================================================
# ORDER
# ================================================================


class OrderCreate(BaseModel):
    customer_name: str = Field(..., min_length=1, max_length=100)
    customer_phone: str = Field(..., min_length=8, max_length=20)
    items: list[OrderItemCreate] = Field(..., min_length=1)
    discount: int = Field(0, ge=0)
    tax_rate: float = Field(0.0, ge=0.0, le=100.0)


class OrderStatusUpdate(BaseModel):
    current_status: str = Field(
        ..., pattern="^(Antrean|Dicuci|Disetrika|Siap Diambil|Selesai)$"
    )


class OrderOut(BaseModel):
    order_id: int
    tracking_code: str
    customer_id: Optional[str] = None
    queue_number: int
    payment_status: str
    current_status: str
    subtotal: int
    discount: int
    tax: int
    grand_total: int
    is_locked: bool
    is_cancelled: bool = False
    order_date: datetime
    customer: Optional[CustomerBrief] = None
    items: list[OrderItemOut] = []

    model_config = {"from_attributes": True}


class OrderListItem(BaseModel):
    order_id: int
    tracking_code: str
    customer_name: Optional[str] = None
    queue_number: int
    payment_status: str
    current_status: str
    grand_total: int
    is_locked: bool
    is_cancelled: bool = False
    order_date: datetime
    item_count: int = 0


# ================================================================
# EDIT REQUEST
# ================================================================


class EditRequestItemCreate(BaseModel):
    order_item_id: Optional[int] = None  # NULL → item baru
    service_type: str = Field(..., pattern="^(Kiloan|Sepatu|Boneka|Karpet|Jas)$")
    new_weight_quantity: Optional[Decimal] = None
    new_price_per_unit: Optional[int] = None


class EditRequestCreate(BaseModel):
    order_id: int
    reason: str = Field(..., min_length=5)
    items: list[EditRequestItemCreate] = Field(..., min_length=1)


class CancelOrderRequest(BaseModel):
    order_id: int
    reason: str = Field(
        ...,
        min_length=10,
        description="Alasan pembatalan — wajib detail karena mempengaruhi data keuangan.",
    )


class EditRequestItemOut(BaseModel):
    request_item_id: int
    request_id: int
    order_item_id: Optional[int] = None
    service_type: str
    old_weight_quantity: Optional[Decimal] = None
    new_weight_quantity: Optional[Decimal] = None
    old_price_per_unit: Optional[int] = None
    new_price_per_unit: Optional[int] = None
    old_item_subtotal: Optional[int] = None
    new_item_subtotal: Optional[int] = None
    is_new_item: bool = False
    is_removed: bool = False

    model_config = {"from_attributes": True}


class EditRequestOut(BaseModel):
    request_id: int
    order_id: int
    requested_by: int
    reason: str
    approval_status: str
    approved_by: Optional[int] = None
    is_cancellation_request: bool = False
    created_at: datetime
    requester_name: Optional[str] = None
    approver_name: Optional[str] = None
    items: list[EditRequestItemOut] = []

    model_config = {"from_attributes": True}


# ================================================================
# TRACKING
# ================================================================


class TrackingResponse(BaseModel):
    tracking_code: str
    customer_name: str
    current_status: str
    status_progress: int
    is_cancelled: bool = False
    queue_position: Optional[int] = None
    queue_ahead: int = 0
    items: list[OrderItemOut] = []
    subtotal: int
    discount: int
    tax: int
    grand_total: int
    order_date: datetime


# ================================================================
# ANALYTICS
# ================================================================


class FinancialSummary(BaseModel):
    period_label: str
    total_orders: int
    total_subtotal: int
    total_discount: int
    total_tax: int
    total_grand_total: int
    total_paid: int
    total_unpaid: int
    avg_grand_total: int


class FinancialAnalyticsResponse(BaseModel):
    summaries: list[FinancialSummary]
    overall: FinancialSummary


class ServiceBreakdown(BaseModel):
    service_type: str
    total_items: int
    total_weight_quantity: Decimal
    total_revenue: int


class ServiceBreakdownResponse(BaseModel):
    breakdown: list[ServiceBreakdown]
