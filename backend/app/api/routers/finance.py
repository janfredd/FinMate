from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import date
from app.core.deps import get_db, get_current_user_id
from app.models.models import Category, Transaction
from app.schemas.schemas import (CategoryIn, CategoryOut, TxnIn, TxnOut)

router = APIRouter()

def _cat_name(db: Session, cid: str | None) -> str | None:
    if not cid:
        return None
    c = db.query(Category).filter_by(id=cid).first()
    return c.name if c else None

def _out(db: Session, t: Transaction) -> TxnOut:
    return TxnOut(id=t.id, user_id=t.user_id, type=t.type, amount=float(t.amount),
                  category_id=t.category_id, date=t.date, merchant=t.merchant,
                  note=t.note, source=t.source, created_at=t.created_at,
                  category_name=_cat_name(db, t.category_id))

# ---- Categories ----
@router.get("/categories", response_model=list[CategoryOut])
def list_cats(uid: str = Depends(get_current_user_id), db: Session = Depends(get_db)):
    rows = db.query(Category).filter(
        (Category.is_default == True) | (Category.user_id == uid)).all()  # noqa: E712
    return [CategoryOut(id=c.id, user_id=c.user_id, name=c.name,
                        is_default=c.is_default) for c in rows]

@router.post("/categories", response_model=CategoryOut, status_code=201)
def create_cat(body: CategoryIn, uid: str = Depends(get_current_user_id),
               db: Session = Depends(get_db)):
    c = Category(user_id=uid, name=body.name.strip(), is_default=False)
    db.add(c)
    db.commit()
    db.refresh(c)
    return CategoryOut(id=c.id, user_id=c.user_id, name=c.name, is_default=False)

@router.put("/categories/{cid}", response_model=CategoryOut)
def rename_cat(cid: str, body: CategoryIn, uid: str = Depends(get_current_user_id),
               db: Session = Depends(get_db)):
    c = db.query(Category).filter_by(id=cid, user_id=uid).first()
    if not c:
        raise HTTPException(404, "Category not found (only custom categories editable)")
    c.name = body.name.strip()
    db.commit()
    return CategoryOut(id=c.id, user_id=c.user_id, name=c.name, is_default=False)

# ---- Transactions ----
@router.get("/transactions", response_model=list[TxnOut])
def list_txns(uid: str = Depends(get_current_user_id), db: Session = Depends(get_db),
              limit: int = 100, offset: int = 0):
    rows = (db.query(Transaction).filter_by(user_id=uid)
            .order_by(Transaction.date.desc(), Transaction.created_at.desc())
            .limit(limit).offset(offset).all())
    return [_out(db, t) for t in rows]

@router.get("/transactions/search", response_model=list[TxnOut])
def search_txns(q: str = "", type: str | None = None, category_id: str | None = None,
                start: date | None = None, end: date | None = None,
                uid: str = Depends(get_current_user_id), db: Session = Depends(get_db)):
    qry = db.query(Transaction).filter_by(user_id=uid)
    if type:
        qry = qry.filter(Transaction.type == type)
    if category_id:
        qry = qry.filter(Transaction.category_id == category_id)
    if start:
        qry = qry.filter(Transaction.date >= start)
    if end:
        qry = qry.filter(Transaction.date <= end)
    if q:
        like = f"%{q}%"
        qry = qry.filter((Transaction.merchant.ilike(like)) |
                         (Transaction.note.ilike(like)))
    return [_out(db, t) for t in qry.order_by(Transaction.date.desc()).limit(200).all()]

@router.post("/transactions", response_model=TxnOut, status_code=201)
def create_txn(body: TxnIn, uid: str = Depends(get_current_user_id),
               db: Session = Depends(get_db)):
    from app.services.budget_service import check_and_notify
    from app.models.models import Budget
    t = Transaction(user_id=uid, type=body.type, amount=body.amount,
                    category_id=body.category_id, date=body.date,
                    merchant=body.merchant, note=body.note, source=body.source)
    db.add(t)
    db.commit()
    db.refresh(t)
    if t.type == "expense" and t.category_id:
        for b in db.query(Budget).filter_by(user_id=uid,
                                            category_id=t.category_id).all():
            if b.start_date <= t.date <= b.end_date:
                check_and_notify(db, uid, b)
    return _out(db, t)

@router.put("/transactions/{tid}", response_model=TxnOut)
def update_txn(tid: str, body: TxnIn, uid: str = Depends(get_current_user_id),
               db: Session = Depends(get_db)):
    t = db.query(Transaction).filter_by(id=tid, user_id=uid).first()
    if not t:
        raise HTTPException(404, "Transaction not found")
    for k, v in body.model_dump().items():
        setattr(t, k, v)
    db.commit()
    db.refresh(t)
    return _out(db, t)

@router.delete("/transactions/{tid}")
def delete_txn(tid: str, uid: str = Depends(get_current_user_id),
               db: Session = Depends(get_db)):
    t = db.query(Transaction).filter_by(id=tid, user_id=uid).first()
    if not t:
        raise HTTPException(404, "Transaction not found")
    db.delete(t)
    db.commit()
    return {"message": "Deleted"}
