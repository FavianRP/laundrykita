"""
Router Edit Requests.
- Kasir: buat edit request, buat cancel request (FR-KSR-04)
- Owner: lihat, approve, reject (FR-OWN-01, FR-OWN-02)
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import inspect, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import require_any_auth, require_kasir, require_owner
from exceptions import BusinessRuleError
from models import EditRequest, EditRequestItem, User
from schemas import (
    CancelOrderRequest,
    EditRequestCreate,
    EditRequestItemOut,
    EditRequestOut,
)
from services.edit_request_service import (
    approve_edit_request,
    create_cancel_request,
    create_edit_request,
    get_edit_request_detail,
    list_edit_requests,
    reject_edit_request,
)

router = APIRouter(prefix="/api/edit-requests", tags=["Edit Requests"])


def _eri_out(eri: EditRequestItem) -> EditRequestItemOut:
    return EditRequestItemOut(
        request_item_id=eri.request_item_id,
        request_id=eri.request_id,
        order_item_id=eri.order_item_id,
        service_type=eri.service_type,
        old_weight_quantity=eri.old_weight_quantity,
        new_weight_quantity=eri.new_weight_quantity,
        old_price_per_unit=eri.old_price_per_unit,
        new_price_per_unit=eri.new_price_per_unit,
        old_item_subtotal=eri.old_item_subtotal,
        new_item_subtotal=eri.new_item_subtotal,
        is_new_item=eri.order_item_id is None,
        is_removed=bool(
            eri.new_weight_quantity is not None and eri.new_weight_quantity == 0
        ),
    )


def _er_out(er: EditRequest, force_items: list | None = None) -> dict:
    if force_items is not None:
        out_items = force_items
    else:
        out_items = inspect(er).attrs["items"].loaded_value
        if not isinstance(out_items, list):
            out_items = []

    return EditRequestOut(
        request_id=er.request_id,
        order_id=er.order_id,
        requested_by=er.requested_by,
        reason=er.reason,
        approval_status=er.approval_status,
        approved_by=er.approved_by,
        is_cancellation_request=er.is_cancellation_request,
        created_at=er.created_at,
        items=[_eri_out(i) for i in out_items],
    ).model_dump()


@router.post("", status_code=201)
async def create(
    body: EditRequestCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(require_kasir),
):
    """Ajukan perbaikan data item order."""
    er = await create_edit_request(body, user.user_id, db)
    er = await get_edit_request_detail(er.request_id, db)
    return _er_out(er)


@router.post("/cancel", status_code=201)
async def request_cancel(
    body: CancelOrderRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(require_kasir),
):
    """Ajukan pembatalan order (soft cancel via approval)."""
    er = await create_cancel_request(body, user.user_id, db)
    return _er_out(er, force_items=[])


@router.get("")
async def index(
    approval_status: str | None = Query(None),
    order_id: int | None = None,
    is_cancellation: bool | None = Query(
        None,
        description="Filter: true=hanya pembatalan, false=hanya edit data, null=semua",
    ),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_any_auth),
):
    requests, total = await list_edit_requests(
        db, approval_status, order_id, is_cancellation, page, page_size
    )

    uids = set()
    for er in requests:
        uids.add(er.requested_by)
        if er.approved_by:
            uids.add(er.approved_by)
    umap = {}
    if uids:
        umap = {
            r.user_id: r.username
            for r in (
                await db.execute(
                    select(User.user_id, User.username).where(User.user_id.in_(uids))
                )
            ).all()
        }

    data = []
    for er in requests:
        out = _er_out(er, force_items=[])
        out["requester_name"] = umap.get(er.requested_by)
        out["approver_name"] = umap.get(er.approved_by) if er.approved_by else None
        data.append(out)

    return {
        "data": data,
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total": total,
            "total_pages": (total + page_size - 1) // page_size if total else 0,
        },
    }


@router.get("/{request_id}")
async def show(
    request_id: int,
    db: AsyncSession = Depends(get_db),
    _user: User = Depends(require_any_auth),
):
    """FR-OWN-01: Git-Diff Audit View — old vs new per item, atau detail pembatalan."""
    er = await get_edit_request_detail(request_id, db)
    if not er:
        raise BusinessRuleError(
            f"Edit Request #{request_id} tidak ditemukan.", status_code=404
        )

    out = _er_out(er)

    uids = [er.requested_by] + ([er.approved_by] if er.approved_by else [])
    umap = {
        r.user_id: r.username
        for r in (
            await db.execute(
                select(User.user_id, User.username).where(User.user_id.in_(uids))
            )
        ).all()
    }
    out["requester_name"] = umap.get(er.requested_by)
    out["approver_name"] = umap.get(er.approved_by) if er.approved_by else None

    return out


@router.post("/{request_id}/approve")
async def approve(
    request_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(require_owner),
):
    """FR-OWN-02: Atomic Approval — edit item ATAU soft cancel."""
    er = await approve_edit_request(request_id, user.user_id, db)
    er = await get_edit_request_detail(er.request_id, db)
    return _er_out(er)


@router.post("/{request_id}/reject")
async def reject(
    request_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(require_owner),
):
    er = await reject_edit_request(request_id, user.user_id, db)
    er = await get_edit_request_detail(er.request_id, db)
    return _er_out(er)
