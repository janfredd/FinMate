"""Budget spend computation + 80%/100% notifications."""
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.models import Budget, Transaction, Insight, Category
from app.services.fcm_service import send_push

def spend_for(db: Session, user_id: str, b: Budget) -> float:
    s = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter(
        Transaction.user_id == user_id, Transaction.type == "expense",
        Transaction.category_id == b.category_id,
        Transaction.date >= b.start_date, Transaction.date <= b.end_date
    ).scalar() or 0
    return float(s)

def check_and_notify(db: Session, user_id: str, b: Budget):
    spent = spend_for(db, user_id, b)
    pct = (spent / float(b.amount) * 100) if float(b.amount) else 0
    cat = db.query(Category).filter_by(id=b.category_id).first()
    name = cat.name if cat else "budget"
    msg = None
    if pct >= 100:
        msg = f"Budget exceeded: {name} {spent:.0f}/{float(b.amount):.0f} ({pct:.0f}%)."
    elif pct >= 80:
        msg = f"Budget warning: {name} reached {pct:.0f}% ({spent:.0f}/{float(b.amount):.0f})."
    if msg:
        # Avoid duplicate spam: skip if identical unread insight exists
        exists = db.query(Insight).filter_by(user_id=user_id, type="budget",
                                             message=msg, is_read=False).first()
        if not exists:
            db.add(Insight(user_id=user_id, type="budget", message=msg))
            db.commit()
            send_push(user_id, "FinMate Budget", msg,
                      {"budget_id": b.id, "pct": f"{pct:.0f}"})
    return spent, pct
