"""
Smart Laundry POS & Automated Governance System
FastAPI Application Entry Point

Cara jalankan:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

NOTED:
- Tidak ada create_all() atau migrasi di sini.
- Skema tabel MySQL ditangani oleh tim DB terpisah (1:1 dengan PRD §4).
- Pastikan MySQL sudah berjalan dan tabel sudah dibuat sebelum start.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import AsyncSessionLocal
from exceptions import register_exception_handlers
from routers import analytics, auth, customers, edit_requests, orders, tracking


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ---- STARTUP ----
    from sqlalchemy import text

    async with AsyncSessionLocal() as session:
        try:
            await session.execute(text("SELECT 1"))
            print("✅ Koneksi database MySQL berhasil.")
        except Exception as e:
            print(f"❌ Gagal konek ke database: {e}")
            print("   Pastikan MySQL berjalan dan tabel sudah dibuat sesuai PRD §4.")
    yield
    # ---- SHUTDOWN ----
    print("🔌 Application shutdown.")


app = FastAPI(
    title="Smart Laundry POS & Automated Governance System",
    description=(
        "Backend API untuk sistem POS laundry multi-layanan "
        "dengan Database-Driven Immutability, Historical Price Preservation, "
        "dan Git-Diff Governance View."
    ),
    version="1.3.0",
    lifespan=lifespan,
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
)

# CORS — adjust di production
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global exception handlers
register_exception_handlers(app)

# Mount routers
app.include_router(auth.router)
app.include_router(orders.router)
app.include_router(tracking.router)
app.include_router(customers.router)
app.include_router(edit_requests.router)
app.include_router(analytics.router)


@app.get("/api/health", tags=["System"])
async def health():
    return {"status": "ok", "version": "1.3.0"}
