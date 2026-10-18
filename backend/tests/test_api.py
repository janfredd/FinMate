"""pytest backend endpoints. Run: pytest -q (needs DATABASE_URL; defaults to sqlite)."""
import os
os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")
from fastapi.testclient import TestClient
from app.main import app
from app.core.deps import Base, engine

Base.metadata.drop_all(bind=engine)
Base.metadata.create_all(bind=engine)
client = TestClient(app)

import uuid

def _auth():
    email = f"t-{uuid.uuid4().hex[:8]}@finmate.app"
    r = client.post("/auth/register", json={"email": email,
                                            "password": "secret123", "name": "T"})
    assert r.status_code in (200, 201), r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}

def test_register_login_profile():
    h = _auth()
    r = client.get("/user/profile", headers=h)
    assert r.status_code == 200, r.text
    r = client.put("/user/profile", headers=h, json={"name": "New"})
    assert r.json()["name"] == "New"

def test_txn_crud_and_dashboard():
    h = _auth()
    cats = client.get("/categories", headers=h).json()
    cid = cats[0]["id"]
    r = client.post("/transactions", headers=h, json={
        "type": "expense", "amount": 50000, "category_id": cid,
        "date": "2026-10-01", "merchant": "Warung", "note": "lunch"})
    assert r.status_code == 201, r.text
    tid = r.json()["id"]
    assert client.get("/transactions", headers=h).status_code == 200
    assert client.get("/transactions/search", headers=h,
                      params={"q": "Warung"}).json()
    r = client.put(f"/transactions/{tid}", headers=h, json={
        "type": "expense", "amount": 60000, "category_id": cid,
        "date": "2026-10-01", "merchant": "Warung", "note": "lunch"})
    assert r.json()["amount"] == 60000
    s = client.get("/dashboard/summary", headers=h).json()
    assert s["total_expense"] >= 60000
    b = client.get("/dashboard/expense-breakdown", headers=h)
    assert b.status_code == 200
    assert client.delete(f"/transactions/{tid}", headers=h).status_code == 200

def test_budget_and_ai():
    h = _auth()
    cid = client.get("/categories", headers=h).json()[0]["id"]
    r = client.post("/budgets", headers=h, json={
        "category_id": cid, "amount": 1000000, "period": "monthly",
        "start_date": "2026-10-01", "end_date": "2026-10-31"})
    assert r.status_code == 201, r.text
    assert client.get("/budgets", headers=h).status_code == 200
    r = client.post("/ai/chat", headers=h,
                    json={"question": "How much did I spend?"})
    assert r.status_code == 200 and r.json()["answer"]
    assert client.get("/insights", headers=h).status_code == 200
