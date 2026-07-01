"""
Custom exceptions & global FastAPI exception handlers.
"""

from fastapi import Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.exc import DBAPIError, IntegrityError


class BusinessRuleError(Exception):
    """Pelanggaran aturan bisnis — akan di-map ke 422 atau status_code kustom."""

    def __init__(
        self, detail: str, status_code: int = status.HTTP_422_UNPROCESSABLE_ENTITY
    ):
        self.detail = detail
        self.status_code = status_code


async def business_rule_handler(request: Request, exc: BusinessRuleError):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


async def integrity_handler(request: Request, exc: IntegrityError):
    msg = str(exc.orig) if exc.orig else str(exc)
    if "Duplicate entry" in msg or "UNIQUE constraint" in msg:
        return JSONResponse(
            status_code=status.HTTP_409_CONFLICT,
            content={
                "detail": "Data duplikat. Kemungkinan nomor telepon atau username sudah terdaftar."
            },
        )
    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content={"detail": "Konflik integritas data pada database."},
    )


async def db_error_handler(request: Request, exc: DBAPIError):
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={"detail": "Kesalahan database. Silakan coba beberapa saat lagi."},
    )


def register_exception_handlers(app):
    app.add_exception_handler(BusinessRuleError, business_rule_handler)
    app.add_exception_handler(IntegrityError, integrity_handler)
    app.add_exception_handler(DBAPIError, db_error_handler)
