from datetime import date, datetime
from pydantic import BaseModel, EmailStr, Field

# ---- Auth ----
class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    name: str | None = None

class LoginIn(BaseModel):
    email: EmailStr
    password: str

class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"

class ResetPasswordIn(BaseModel):
    email: EmailStr

# ---- User ----
class ProfileOut(BaseModel):
    id: str
    email: str
    name: str | None
    created_at: datetime | None

class ProfileUpdate(BaseModel):
    name: str | None = None
    email: EmailStr | None = None

# ---- Categories ----
class CategoryIn(BaseModel):
    name: str = Field(min_length=1, max_length=64)

class CategoryOut(BaseModel):
    id: str
    user_id: str | None
    name: str
    is_default: bool

# ---- Transactions ----
class TxnIn(BaseModel):
    type: str = Field(pattern="^(income|expense)$")
    amount: float = Field(gt=0)
    category_id: str | None = None
    date: date
    merchant: str | None = None
    note: str | None = None
    source: str = "Manual"

class TxnOut(TxnIn):
    id: str
    user_id: str
    created_at: datetime | None
    category_name: str | None = None

# ---- Budgets ----
class BudgetIn(BaseModel):
    category_id: str
    amount: float = Field(gt=0)
    period: str = Field(default="monthly", pattern="^(monthly|weekly)$")
    start_date: date
    end_date: date

class BudgetOut(BudgetIn):
    id: str
    user_id: str
    spent: float = 0.0
    pct: float = 0.0
    category_name: str | None = None

# ---- AI / Insights ----
class ChatIn(BaseModel):
    question: str = Field(min_length=1, max_length=2000)

class ChatOut(BaseModel):
    answer: str

class InsightOut(BaseModel):
    id: str
    type: str
    message: str
    created_at: datetime | None
    is_read: bool

# ---- Dashboard ----
class SummaryOut(BaseModel):
    total_income: float
    total_expense: float
    balance: float
    savings: float

class BreakdownItem(BaseModel):
    category_id: str | None
    category_name: str
    total: float
