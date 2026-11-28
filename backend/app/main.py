"""FinMate FastAPI backend. Run: uvicorn app.main:app --reload"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text
from apscheduler.schedulers.background import BackgroundScheduler
from app.core.config import settings
from app.core.deps import Base, engine
from app.models import models  # noqa: F401  (register tables)
from app.api.routers.ai import router as ai_router
from app.api.routers.auth import router as auth_router
from app.api.routers.finance import router as finance_router
from app.api.routers.insight import router as insight_router
from app.api.routers.payment import router as payment_router

scheduler = BackgroundScheduler()

def _cron_import():
    # Cron: every 15 min import Gmail for all connected users.
    from app.core.deps import SessionLocal
    from app.models.models import OAuthToken
    from app.services.gmail_service import import_unread
    db = SessionLocal()
    try:
        for row in db.query(OAuthToken).all():
            try:
                import_unread(db, row.user_id)
            except Exception:
                pass
    finally:
        db.close()

def _migrate_sqlite():
    """Add premium/AI-limit columns to existing SQLite databases."""
    if engine.dialect.name != "sqlite":
        return
    insp = inspect(engine)
    if "users" not in insp.get_table_names():
        return
    cols = {c["name"] for c in insp.get_columns("users")}
    with engine.begin() as conn:
        if "is_premium" not in cols:
            conn.execute(text(
                "ALTER TABLE users ADD COLUMN is_premium BOOLEAN NOT NULL "
                "DEFAULT 0"))
        if "ai_messages_today" not in cols:
            conn.execute(text(
                "ALTER TABLE users ADD COLUMN ai_messages_today INTEGER NOT "
                "NULL DEFAULT 0"))
        if "last_ai_message_date" not in cols:
            conn.execute(text(
                "ALTER TABLE users ADD COLUMN last_ai_message_date DATE"))

@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    _migrate_sqlite()
    scheduler.add_job(_cron_import, "interval", minutes=15, id="gmail_import")
    scheduler.start()
    yield
    scheduler.shutdown()

app = FastAPI(title="FinMate API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=[settings.CORS_ORIGINS] if settings.CORS_ORIGINS != "*" else ["*"],
                   allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

# Auth + user (paths embed /auth and /user per spec)
app.include_router(auth_router, tags=["auth"])
# Finance: transactions/categories
app.include_router(finance_router, tags=["finance"])
# Dashboard/budgets/AI/insights/gmail
app.include_router(insight_router, tags=["insights"])
# Voice input parsing
app.include_router(ai_router, tags=["ai"])
# Midtrans Snap checkout + webhook
app.include_router(payment_router)

@app.get("/health")
def health():
    return {"status": "ok"}
