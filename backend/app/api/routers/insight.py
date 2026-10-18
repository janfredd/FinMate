from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.deps import get_db, get_current_user_id
from app.models.models import Transaction, Budget, Category, Insight, OAuthToken
from app.schemas.schemas import (BudgetIn, BudgetOut, SummaryOut, BreakdownItem,
                                 ChatIn, ChatOut, InsightOut)
from app.services.budget_service import spend_for, check_and_notify
from app.services.ai_service import ask_gemini, build_context, generate_proactive_insights
from app.services.gmail_service import auth_url, exchange_code, save_tokens, import_unread
import uuid

router = APIRouter()

# ---- Dashboard ----
@router.get("/dashboard/summary", response_model=SummaryOut)
def summary(uid: str = Depends(get_current_user_id), db: Session = Depends(get_db)):
    inc = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter_by(
        user_id=uid, type="income").scalar() or 0
    exp = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter_by(
        user_id=uid, type="expense").scalar() or 0
    inc, exp = float(inc), float(exp)
    return SummaryOut(total_income=inc, total_expense=exp,
                      balance=inc - exp, savings=inc - exp)

@router.get("/dashboard/expense-breakdown", response_model=list[BreakdownItem])
def breakdown(uid: str = Depends(get_current_user_id), db: Session = Depends(get_db)):
    rows = (db.query(Transaction.category_id, func.sum(Transaction.amount))
            .filter_by(user_id=uid, type="expense")
            .group_by(Transaction.category_id).all())
    names = {c.id: c.name for c in db.query(Category).all()}
    return [BreakdownItem(category_id=r[0], category_name=names.get(r[0], "-"),
                          total=float(r[1])) for r in rows]

# ---- Budgets ----
def _bout(db: Session, uid: str, b: Budget) -> BudgetOut:
    spent = spend_for(db, uid, b)
    pct = spent / float(b.amount) * 100 if float(b.amount) else 0
    c = db.query(Category).filter_by(id=b.category_id).first()
    return BudgetOut(id=b.id, user_id=b.user_id, category_id=b.category_id,
                     amount=float(b.amount), period=b.period,
                     start_date=b.start_date, end_date=b.end_date,
                     spent=spent, pct=pct, category_name=c.name if c else None)

@router.get("/budgets", response_model=list[BudgetOut])
def list_budgets(uid: str = Depends(get_current_user_id), db: Session = Depends(get_db)):
    return [_bout(db, uid, b) for b in db.query(Budget).filter_by(user_id=uid).all()]

@router.post("/budgets", response_model=BudgetOut, status_code=201)
def create_budget(body: BudgetIn, uid: str = Depends(get_current_user_id),
                  db: Session = Depends(get_db)):
    b = Budget(user_id=uid, **body.model_dump())
    db.add(b)
    db.commit()
    db.refresh(b)
    check_and_notify(db, uid, b)
    return _bout(db, uid, b)

@router.put("/budgets/{bid}", response_model=BudgetOut)
def update_budget(bid: str, body: BudgetIn, uid: str = Depends(get_current_user_id),
                  db: Session = Depends(get_db)):
    b = db.query(Budget).filter_by(id=bid, user_id=uid).first()
    if not b:
        raise HTTPException(404, "Budget not found")
    for k, v in body.model_dump().items():
        setattr(b, k, v)
    db.commit()
    db.refresh(b)
    check_and_notify(db, uid, b)
    return _bout(db, uid, b)

# ---- AI ----
@router.post("/ai/chat", response_model=ChatOut)
async def ai_chat(body: ChatIn, uid: str = Depends(get_current_user_id),
                  db: Session = Depends(get_db)):
    ctx = build_context(db, uid)
    prompt = ("You are a financial assistant. Based on these transactions "
              f"(date | type | amount | category | merchant | note):\n{ctx}\n\n"
              f"Answer concisely: {body.question}")
    answer = await ask_gemini(prompt)
    db.add(Insight(user_id=uid, type="chat",
                   message=f"Q: {body.question[:500]}\nA: {answer[:2000]}"))
    db.commit()
    return ChatOut(answer=answer)

@router.get("/insights", response_model=list[InsightOut])
def insights(uid: str = Depends(get_current_user_id), db: Session = Depends(get_db),
             refresh: bool = False):
    if refresh:
        generate_proactive_insights(db, uid)
    rows = (db.query(Insight).filter_by(user_id=uid)
            .order_by(Insight.created_at.desc()).limit(50).all())
    return [InsightOut(id=i.id, type=i.type, message=i.message,
                       created_at=i.created_at, is_read=i.is_read) for i in rows]

# ---- Gmail OAuth ----
@router.post("/oauth/gmail/connect")
def gmail_connect(uid: str = Depends(get_current_user_id)):
    return {"auth_url": auth_url(state=uid)}

@router.get("/oauth/gmail/callback")
def gmail_callback(code: str, state: str, db: Session = Depends(get_db)):
    save_tokens(db, state, exchange_code(code))
    return {"message": "Gmail connected."}

@router.post("/oauth/gmail/revoke")
def gmail_revoke(uid: str = Depends(get_current_user_id),
                 db: Session = Depends(get_db)):
    db.query(OAuthToken).filter_by(user_id=uid).delete()
    db.commit()
    return {"message": "Gmail access revoked."}

@router.post("/gmail/import")
def gmail_import(uid: str = Depends(get_current_user_id),
                 db: Session = Depends(get_db)):
    n = import_unread(db, uid)
    return {"imported": n}
