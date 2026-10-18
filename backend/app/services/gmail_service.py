"""Gmail import: OAuth URL, token exchange, unread bank-email scan."""
import base64, re
from datetime import datetime, date
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import Flow
from sqlalchemy.orm import Session
from app.core.config import settings
from app.core.security import encrypt_token, decrypt_token
from app.models.models import OAuthToken, Transaction, Category
from app.services.parsers import parse_amount, detect_type, looks_like_bank_email

SCOPES = ["https://www.googleapis.com/auth/gmail.readonly"]

def auth_url(state: str) -> str:
    flow = Flow.from_client_config(
        {"web": {"client_id": settings.GOOGLE_CLIENT_ID,
                 "client_secret": settings.GOOGLE_CLIENT_SECRET,
                 "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                 "token_uri": "https://oauth2.googleapis.com/token",
                 "redirect_uris": [settings.GOOGLE_REDIRECT_URI]}},
        scopes=SCOPES, redirect_uri=settings.GOOGLE_REDIRECT_URI)
    url, _ = flow.authorization_url(access_type="offline", prompt="consent",
                                    include_granted_scopes="true", state=state)
    return url

def exchange_code(code: str) -> dict:
    flow = Flow.from_client_config(
        {"web": {"client_id": settings.GOOGLE_CLIENT_ID,
                 "client_secret": settings.GOOGLE_CLIENT_SECRET,
                 "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                 "token_uri": "https://oauth2.googleapis.com/token",
                 "redirect_uris": [settings.GOOGLE_REDIRECT_URI]}},
        scopes=SCOPES, redirect_uri=settings.GOOGLE_REDIRECT_URI)
    flow.fetch_token(code=code)
    return {"access_token": flow.credentials.token,
            "refresh_token": flow.credentials.refresh_token or "",
            "expiry": flow.credentials.expiry}

def save_tokens(db: Session, user_id: str, toks: dict):
    row = db.query(OAuthToken).filter_by(user_id=user_id).first()
    if not row:
        row = OAuthToken(user_id=user_id, access_token="", refresh_token="")
        db.add(row)
    row.access_token = encrypt_token(toks["access_token"])
    row.refresh_token = encrypt_token(toks.get("refresh_token", ""))
    row.expiry = toks.get("expiry")
    db.commit()

def _gmail(db: Session, user_id: str):
    row = db.query(OAuthToken).filter_by(user_id=user_id).first()
    if not row:
        return None
    creds = Credentials(token=decrypt_token(row.access_token),
                        refresh_token=decrypt_token(row.refresh_token),
                        token_uri="https://oauth2.googleapis.com/token",
                        client_id=settings.GOOGLE_CLIENT_ID,
                        client_secret=settings.GOOGLE_CLIENT_SECRET)
    if creds.expired and creds.refresh_token:
        creds.refresh()
        save_tokens(db, user_id, {"access_token": creds.token,
                                  "refresh_token": creds.refresh_token,
                                  "expiry": creds.expiry})
    return build("gmail", "v1", credentials=creds)

def _body(payload) -> str:
    if payload.get("body", {}).get("data"):
        return base64.urlsafe_b64decode(payload["body"]["data"]).decode("utf-8", "ignore")
    text = ""
    for p in payload.get("parts", []):
        text += _body(p) + "\n"
    return text

def _others_cat(db: Session) -> str | None:
    c = db.query(Category).filter(Category.name == "Others",
                                  Category.user_id.is_(None)).first()
    return c.id if c else None

def import_unread(db: Session, user_id: str, max_n: int = 20) -> int:
    svc = _gmail(db, user_id)
    if not svc:
        return 0
    res = svc.users().messages().list(userId="me", q="is:unread newer_than:7d",
                                      maxResults=max_n).execute()
    saved = 0
    for m in res.get("messages", []):
        full = svc.users().messages().get(userId="me", id=m["id"],
                                          format="full").execute()
        headers = {h["name"].lower(): h["value"]
                   for h in full["payload"].get("headers", [])}
        subject = headers.get("subject", "")
        body = _body(full["payload"])
        if not looks_like_bank_email(subject, body):
            continue
        amt = parse_amount(subject + "\n" + body)
        if not amt:
            continue
        ttype = detect_type(subject + " " + body)
        merchant = (headers.get("from", "") or subject)[:120]
        db.add(Transaction(user_id=user_id, type=ttype, amount=amt,
                           category_id=_others_cat(db), date=date.today(),
                           merchant=merchant, note=subject[:255], source="Email"))
        saved += 1
        svc.users().messages().modify(userId="me", id=m["id"],
                                      body={"removeLabelIds": ["UNREAD"]}).execute()
    db.commit()
    return saved
