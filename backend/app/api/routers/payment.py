"""Midtrans Snap checkout + webhook."""
import hashlib
import hmac
import logging
import time

from fastapi import APIRouter, Depends, HTTPException, Request
from midtransclient import Snap
from midtransclient.error_midtrans import MidtransAPIError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.deps import get_db, get_current_user_id
from app.models.models import User
from app.schemas.schemas import PaymentRequest, PaymentResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/payments", tags=["payments"])


def _snap() -> Snap:
    server_key = (settings.MIDTRANS_SERVER_KEY or "").strip()
    if not server_key:
        raise HTTPException(
            status_code=500,
            detail=("MIDTRANS_SERVER_KEY belum dikonfigurasi. Isi server key "
                    "Sandbox (diawali 'SB-Mid-') di file .env backend."),
        )
    if not server_key.startswith("SB-Mid-"):
        raise HTTPException(
            status_code=500,
            detail=("MIDTRANS_SERVER_KEY tidak valid untuk Sandbox. Gunakan "
                    "server key Sandbox yang diawali 'SB-Mid-'."),
        )
    return Snap(
        is_production=False,
        server_key=server_key,
        client_key=settings.MIDTRANS_CLIENT_KEY,
    )


def _verify_signature(payload: dict) -> bool:
    raw = (
        f"{payload.get('order_id', '')}"
        f"{payload.get('status_code', '')}"
        f"{payload.get('gross_amount', '')}"
        f"{(settings.MIDTRANS_SERVER_KEY or '').strip()}"
    )
    expected = hashlib.sha512(raw.encode("utf-8")).hexdigest()
    return hmac.compare_digest(expected, str(payload.get("signature_key", "")))


def _order_id(uid: str) -> str:
    """Unique, <=50 char order id that still embeds the user id.

    Midtrans limits order_id to 50 characters, so the 36-char UUID is stored
    without dashes under a short prefix.
    """
    compact = uid.replace("-", "")
    return f"FM-{compact}-{int(time.time() * 1000)}"


def _user_id_from_order(order_id: str) -> str | None:
    if order_id.startswith("FM-"):
        compact, sep, _ = order_id[3:].rpartition("-")
        if sep and len(compact) == 32:
            return (f"{compact[:8]}-{compact[8:12]}-{compact[12:16]}-"
                    f"{compact[16:20]}-{compact[20:]}")
        return None
    prefix = "FINMATE-"
    if not order_id.startswith(prefix):
        return None
    uid, sep, _ = order_id[len(prefix):].rpartition("-")
    return uid if sep and uid else None


@router.post("/checkout", response_model=PaymentResponse)
def checkout(
    body: PaymentRequest,
    uid: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter_by(id=uid).first()
    if not user:
        raise HTTPException(404, "User not found")

    gross_amount = int(round(body.amount))
    if gross_amount <= 0:
        raise HTTPException(400, "gross_amount harus lebih besar dari 0")
    order_id = _order_id(uid)
    params = {
        "transaction_details": {
            "order_id": order_id,
            "gross_amount": gross_amount,
        },
        "item_details": [
            {
                "id": "premium",
                "price": gross_amount,
                "quantity": 1,
                "name": body.plan_name,
            }
        ],
        "customer_details": {
            "first_name": user.name or user.email.split("@")[0],
            "email": user.email,
        },
    }
    snap = _snap()
    try:
        txn = snap.create_transaction(params)
    except Exception as exc:
        logger.exception("Midtrans create_transaction failed for order %s",
                         order_id)
        print(f"[Midtrans] create_transaction error ({order_id}): {exc}",
              flush=True)
        raise HTTPException(
            status_code=500,
            detail=f"Midtrans error: {exc}",
        ) from exc

    return PaymentResponse(
        order_id=order_id,
        token=txn.get("token", ""),
        redirect_url=txn.get("redirect_url", ""),
    )


@router.get("/check-status/{order_id}")
def check_status(
    order_id: str,
    uid: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """Poll Midtrans for the latest status and sync premium locally."""
    if _user_id_from_order(order_id) != uid:
        raise HTTPException(403, "Order ini bukan milik pengguna.")
    user = db.query(User).filter_by(id=uid).first()
    if not user:
        raise HTTPException(404, "User not found")

    snap = _snap()
    try:
        status = snap.transactions.status(order_id)
    except MidtransAPIError as exc:
        # Snap transactions only appear in Core API Get Status after the
        # customer picks a payment method. Before that Midtrans returns 404
        # (sometimes as HTTP 200 with status_code 404 in the JSON body).
        api_status = str((exc.api_response_dict or {}).get("status_code") or "")
        if exc.http_status_code == 404 or api_status == "404":
            return {
                "order_id": order_id,
                "transaction_status": "pending",
                "fraud_status": "",
                "success": False,
                "is_premium": bool(user.is_premium),
            }
        logger.exception("Midtrans status check failed for order %s", order_id)
        print(f"[Midtrans] status error ({order_id}): {exc}", flush=True)
        raise HTTPException(
            status_code=500,
            detail=f"Midtrans status error: {exc}",
        ) from exc
    except Exception as exc:
        logger.exception("Midtrans status check failed for order %s", order_id)
        print(f"[Midtrans] status error ({order_id}): {exc}", flush=True)
        raise HTTPException(
            status_code=500,
            detail=f"Midtrans status error: {exc}",
        ) from exc

    tx_status = str(status.get("transaction_status") or "").lower()
    fraud_status = str(status.get("fraud_status") or "").lower()
    paid = tx_status == "settlement" or (
        tx_status == "capture" and fraud_status in ("accept", ""))
    if paid and not user.is_premium:
        user.is_premium = True
        db.commit()
        db.refresh(user)

    return {
        "order_id": order_id,
        "transaction_status": tx_status,
        "fraud_status": fraud_status,
        "success": paid,
        "is_premium": bool(user.is_premium),
    }


@router.post("/webhook")
async def webhook(request: Request, db: Session = Depends(get_db)):
    payload = await request.json()
    if not _verify_signature(payload):
        raise HTTPException(403, "Invalid signature")

    status = payload.get("transaction_status")
    fraud = payload.get("fraud_status")
    paid = status == "settlement" or (status == "capture" and fraud == "accept")
    if paid:
        uid = _user_id_from_order(str(payload.get("order_id", "")))
        if uid:
            user = db.query(User).filter_by(id=uid).first()
            if user and not user.is_premium:
                user.is_premium = True
                db.commit()
    return {"status": "ok"}
