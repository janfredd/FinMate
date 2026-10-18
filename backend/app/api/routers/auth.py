from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.deps import get_db, get_current_user_id
from app.core.security import hash_password, verify_password, create_access_token
from app.models.models import User, Category, Transaction, Budget, OAuthToken, Insight
from app.schemas.schemas import (RegisterIn, LoginIn, TokenOut, ResetPasswordIn,
                                 ProfileOut, ProfileUpdate)

router = APIRouter()
DEFAULT_CATS = ["Food", "Transportation", "Shopping", "Entertainment",
                "Bills", "Health", "Education", "Others"]

def _seed_defaults(db: Session):
    if not db.query(Category).filter_by(is_default=True).first():
        for n in DEFAULT_CATS:
            db.add(Category(user_id=None, name=n, is_default=True))
        db.commit()

@router.post("/auth/register", response_model=TokenOut, status_code=201)
def register(body: RegisterIn, db: Session = Depends(get_db)):
    _seed_defaults(db)
    if db.query(User).filter_by(email=body.email.lower()).first():
        raise HTTPException(400, "Email already registered")
    u = User(email=body.email.lower(), password_hash=hash_password(body.password),
             name=body.name)
    db.add(u)
    db.commit()
    db.refresh(u)
    return TokenOut(access_token=create_access_token(u.id))

@router.post("/auth/login", response_model=TokenOut)
def login(body: LoginIn, db: Session = Depends(get_db)):
    u = db.query(User).filter_by(email=body.email.lower()).first()
    if not u or not verify_password(body.password, u.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid credentials")
    return TokenOut(access_token=create_access_token(u.id))

@router.post("/auth/logout")
def logout():
    # Stateless JWT: client discards token. Endpoint exists per spec.
    return {"message": "Logged out. Discard token client-side."}

@router.post("/auth/reset-password")
def reset_password(body: ResetPasswordIn, db: Session = Depends(get_db)):
    # Do not leak existence; in prod send Supabase/SMTP email here.
    u = db.query(User).filter_by(email=body.email.lower()).first()
    if u:
        pass  # TODO: send reset email via Supabase Auth / SMTP
    return {"message": "If the email exists, a reset link was sent."}

@router.get("/user/profile", response_model=ProfileOut)
def get_profile(uid: str = Depends(get_current_user_id), db: Session = Depends(get_db)):
    u = db.query(User).filter_by(id=uid).first()
    if not u:
        raise HTTPException(404, "User not found")
    return ProfileOut(id=u.id, email=u.email, name=u.name, created_at=u.created_at)

@router.put("/user/profile", response_model=ProfileOut)
def update_profile(body: ProfileUpdate, uid: str = Depends(get_current_user_id),
                   db: Session = Depends(get_db)):
    u = db.query(User).filter_by(id=uid).first()
    if not u:
        raise HTTPException(404, "User not found")
    if body.name is not None:
        u.name = body.name
    if body.email is not None:
        if db.query(User).filter(User.email == body.email.lower(),
                                 User.id != uid).first():
            raise HTTPException(400, "Email already in use")
        u.email = body.email.lower()
    db.commit()
    db.refresh(u)
    return ProfileOut(id=u.id, email=u.email, name=u.name, created_at=u.created_at)

@router.delete("/user/account")
def delete_account(uid: str = Depends(get_current_user_id),
                   db: Session = Depends(get_db)):
    # Order matters (FK): insights, oauth, txns, budgets, custom cats, user
    db.query(Insight).filter_by(user_id=uid).delete()
    db.query(OAuthToken).filter_by(user_id=uid).delete()
    db.query(Transaction).filter_by(user_id=uid).delete()
    db.query(Budget).filter_by(user_id=uid).delete()
    db.query(Category).filter(Category.user_id == uid).delete()
    db.query(User).filter_by(id=uid).delete()
    db.commit()
    return {"message": "Account and all user data deleted."}
