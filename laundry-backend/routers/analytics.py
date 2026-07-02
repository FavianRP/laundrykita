"""
Router Analytics — akses owner only.
FR-OWN-03: Financial Analytics Engine.
"""

from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import require_owner
from services.analytics_service import get_financial_analytics, get_service_breakdown

router = APIRouter(prefix="/api/analytics", tags=["Analytics & Laporan"])


@router.get("/financial")
async def financial(
    date_from: date = Query(..., description="YYYY-MM-DD"),
    date_to: date = Query(..., description="YYYY-MM-DD"),
    group_by: str = Query("day", pattern="^(day|week|month)$"),
    db: AsyncSession = Depends(get_db),
    _owner=Depends(require_owner),
):
    return (
        await get_financial_analytics(db, date_from, date_to, group_by)
    ).model_dump()


@router.get("/service-breakdown")
async def service_breakdown(
    date_from: date = Query(...),
    date_to: date = Query(...),
    db: AsyncSession = Depends(get_db),
    _owner=Depends(require_owner),
):
    return (await get_service_breakdown(db, date_from, date_to)).model_dump()
