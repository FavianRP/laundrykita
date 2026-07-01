"""
SQLAlchemy ORM Models — mapping 1:1 ke skema MySQL di PRD + soft cancel.
Tabel: users, customers, orders, order_items, edit_requests, edit_request_items
"""

from database import Base
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func


class User(Base):
    __tablename__ = "users"

    user_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(10), nullable=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime, server_default=func.now())

    edit_requests_made = relationship(
        "EditRequest",
        foreign_keys="EditRequest.requested_by",
        back_populates="requester",
    )
    edit_requests_approved = relationship(
        "EditRequest", foreign_keys="EditRequest.approved_by", back_populates="approver"
    )


class Customer(Base):
    __tablename__ = "customers"

    customer_id: Mapped[str] = mapped_column(String(20), primary_key=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    phone_number: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime, server_default=func.now())

    orders = relationship("Order", back_populates="customer")


class Order(Base):
    __tablename__ = "orders"

    order_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    customer_id: Mapped[str | None] = mapped_column(
        String(20), ForeignKey("customers.customer_id"), nullable=True
    )
    queue_number: Mapped[int] = mapped_column(Integer, nullable=False)
    payment_status: Mapped[str] = mapped_column(String(20), default="Belum Lunas")
    current_status: Mapped[str] = mapped_column(String(20), default="Antrean")
    subtotal: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    discount: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    tax: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    grand_total: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_locked: Mapped[bool] = mapped_column(Boolean, default=False)
    is_cancelled: Mapped[bool] = mapped_column(Boolean, default=False)
    order_date: Mapped[DateTime] = mapped_column(DateTime, server_default=func.now())

    customer = relationship("Customer", back_populates="orders")
    items = relationship(
        "OrderItem", back_populates="order", cascade="all, delete-orphan"
    )
    edit_requests = relationship("EditRequest", back_populates="order")

    __table_args__ = (
        CheckConstraint(
            "payment_status IN ('Belum Lunas', 'Lunas')", name="ck_payment_status"
        ),
        CheckConstraint(
            "current_status IN ('Antrean', 'Dicuci', 'Disetrika', 'Siap Diambil', 'Selesai')",
            name="ck_current_status",
        ),
        CheckConstraint("is_locked IN (0, 1)", name="ck_is_locked"),
        CheckConstraint("is_cancelled IN (0, 1)", name="ck_is_cancelled"),
    )


class OrderItem(Base):
    __tablename__ = "order_items"

    item_id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    order_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("orders.order_id", ondelete="CASCADE"), nullable=False
    )
    service_type: Mapped[str] = mapped_column(String(20), nullable=False)
    weight_quantity: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False)
    price_per_unit: Mapped[int] = mapped_column(Integer, nullable=False)
    item_subtotal: Mapped[int] = mapped_column(Integer, nullable=False)

    order = relationship("Order", back_populates="items")

    __table_args__ = (
        CheckConstraint(
            "service_type IN ('Kiloan', 'Sepatu', 'Boneka', 'Karpet', 'Jas')",
            name="ck_service_type",
        ),
    )


class EditRequest(Base):
    __tablename__ = "edit_requests"

    request_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    order_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("orders.order_id"), nullable=False
    )
    requested_by: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.user_id"), nullable=False
    )
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    approval_status: Mapped[str] = mapped_column(String(20), default="Pending")
    approved_by: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("users.user_id"), nullable=True
    )
    is_cancellation_request: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime, server_default=func.now())

    order = relationship("Order", back_populates="edit_requests")
    requester = relationship(
        "User", foreign_keys=[requested_by], back_populates="edit_requests_made"
    )
    approver = relationship(
        "User", foreign_keys=[approved_by], back_populates="edit_requests_approved"
    )
    items = relationship(
        "EditRequestItem", back_populates="edit_request", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint(
            "approval_status IN ('Pending', 'Approved', 'Rejected')",
            name="ck_approval_status",
        ),
        CheckConstraint(
            "is_cancellation_request IN (0, 1)", name="ck_is_cancellation_request"
        ),
    )


class EditRequestItem(Base):
    __tablename__ = "edit_request_items"

    request_item_id: Mapped[int] = mapped_column(
        Integer, primary_key=True, autoincrement=True
    )
    request_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("edit_requests.request_id", ondelete="CASCADE"),
        nullable=False,
    )
    order_item_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    service_type: Mapped[str] = mapped_column(String(20), nullable=False)
    old_weight_quantity: Mapped[float | None] = mapped_column(
        Numeric(5, 2), nullable=True
    )
    new_weight_quantity: Mapped[float | None] = mapped_column(
        Numeric(5, 2), nullable=True
    )
    old_price_per_unit: Mapped[int | None] = mapped_column(Integer, nullable=True)
    new_price_per_unit: Mapped[int | None] = mapped_column(Integer, nullable=True)
    old_item_subtotal: Mapped[int | None] = mapped_column(Integer, nullable=True)
    new_item_subtotal: Mapped[int | None] = mapped_column(Integer, nullable=True)

    edit_request = relationship("EditRequest", back_populates="items")
