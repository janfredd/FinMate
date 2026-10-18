"""Gemini API call + proactive insight generation."""
import httpx
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import date, timedelta
from app.core.config import settings
from app.models.models import Transaction, Category, Insight

GEMINI_URL = ("https://generativelanguage.googleapis.com/v1beta/models/"
              "{model}:generateContent?key={key}")

async def ask_gemini(prompt: str) -> str:
    if not settings.GEMINI_API_KEY:
        # Offline/dev fallback keeps the endpoint testable without a key.
        return "(Gemini API key not configured) Echo of prompt:\n" + prompt[:2000]
    url = GEMINI_URL.format(model=settings.GEMINI_MODEL, key=settings.GEMINI_API_KEY)
    body = {"contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"maxOutputTokens": 1024, "temperature": 0.4}}
    async with httpx.AsyncClient(timeout=30) as c:
        r = await c.post(url, json=body)
        r.raise_for_status()
        data = r.json()
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError):
        return "Sorry, I could not generate a response right now."

def build_context(db: Session, user_id: str, limit: int = 100) -> str:
    txns = (db.query(Transaction).filter(Transaction.user_id == user_id)
            .order_by(Transaction.date.desc()).limit(limit).all())
    if not txns:
        return "No transactions recorded yet."
    cat = {c.id: c.name for c in db.query(Category).all()}
    lines = []
    for t in txns:
        lines.append(f"{t.date} | {t.type} | {float(t.amount):.2f} | "
                     f"{cat.get(t.category_id, '-')} | {t.merchant or '-'} | {t.note or ''}")
    return "\n".join(lines)

def generate_proactive_insights(db: Session, user_id: str) -> list[str]:
    """Rule-based: spikes per category vs previous 30d, budget-free saving tips."""
    today = date.today()
    cur_start, prev_start = today - timedelta(days=30), today - timedelta(days=60)
    msgs: list[str] = []
    cats = db.query(Category).all()
    cat_name = {c.id: c.name for c in cats}
    for cid, name in cat_name.items():
        cur = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter(
            Transaction.user_id == user_id, Transaction.type == "expense",
            Transaction.category_id == cid,
            Transaction.date >= cur_start).scalar() or 0
        prev = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter(
            Transaction.user_id == user_id, Transaction.type == "expense",
            Transaction.category_id == cid,
            Transaction.date >= prev_start, Transaction.date < cur_start).scalar() or 0
        if prev > 0 and cur > prev * 1.5:
            pct = (cur - prev) / prev * 100
            msgs.append(f"Unusual spike: {name} spending rose {pct:.0f}% "
                        f"({float(prev):.0f} → {float(cur):.0f}) in the last 30 days.")
    total = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter(
        Transaction.user_id == user_id, Transaction.type == "expense",
        Transaction.date >= cur_start).scalar() or 0
    if total > 0:
        top = (db.query(Transaction.category_id, func.sum(Transaction.amount).label("s"))
               .filter(Transaction.user_id == user_id, Transaction.type == "expense",
                       Transaction.date >= cur_start)
               .group_by(Transaction.category_id).order_by(func.sum(Transaction.amount).desc())
               .first())
        if top and top[1]:
            msgs.append(f"Saving opportunity: your top category is "
                        f"{cat_name.get(top[0], '?')} ({float(top[1]):.0f}). "
                        f"Cutting 10% could save {float(top[1]) * 0.1:.0f} next month.")
    for m in msgs:
        db.add(Insight(user_id=user_id, type="proactive", message=m))
    db.commit()
    return msgs
