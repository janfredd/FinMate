"""SQLAlchemy models matching SRS/SDD schema (Supabase PostgreSQL)."""
import uuid
from datetime import datetime, date
from sqlalchemy import (Column, String, Text, Numeric, Date, DateTime,
                        Boolean, ForeignKey)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import relationship
from app.core.deps import Base

def _uuid():
    return str(uuid.uuid4())

class User(Base):
    __tablename__ = "users"
    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=_uuid)
    email = Column(Text, unique=True, nullable=False, index=True)
    password_hash = Column(Text, nullable=False)
    name = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Category(Base):
    __tablename__ = "categories"
    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(PG_UUID(as_uuid=False), ForeignKey("users.id"), nullable=True)
    name = Column(Text, nullable=False)
    is_default = Column(Boolean, default=False)

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(PG_UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, index=True)
    type = Column(Text, nullable=False)  # income | expense
    amount = Column(Numeric(14, 2), nullable=False)
    category_id = Column(PG_UUID(as_uuid=False), ForeignKey("categories.id"), nullable=True)
    date = Column(Date, nullable=False, default=date.today, index=True)
    merchant = Column(Text, nullable=True)
    note = Column(Text, nullable=True)
    source = Column(Text, default="Manual")  # Manual | Email | Receipt
    created_at = Column(DateTime, default=datetime.utcnow)

class Budget(Base):
    __tablename__ = "budgets"
    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(PG_UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, index=True)
    category_id = Column(PG_UUID(as_uuid=False), ForeignKey("categories.id"), nullable=False)
    amount = Column(Numeric(14, 2), nullable=False)
    period = Column(Text, default="monthly")  # monthly | weekly
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=False)

class OAuthToken(Base):
    __tablename__ = "oauth_tokens"
    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(PG_UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, unique=True)
    access_token = Column(Text, nullable=False)   # Fernet-encrypted
    refresh_token = Column(Text, nullable=False)  # Fernet-encrypted
    expiry = Column(DateTime, nullable=True)

class Insight(Base):
    __tablename__ = "insights"
    id = Column(PG_UUID(as_uuid=False), primary_key=True, default=_uuid)
    user_id = Column(PG_UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, index=True)
    type = Column(Text, nullable=False)  # chat | proactive | budget
    message = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    is_read = Column(Boolean, default=False)
