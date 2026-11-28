from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.deps import get_db, get_current_user_id
from app.models.models import Insight, User
from app.schemas.schemas import (VoiceParseIn, VoiceParseOut, ChatIn, ChatOut)
from app.services.ai_service import (parse_voice_transaction, ask_ai,
                                     build_context)

router = APIRouter()


@router.post("/ai/chat", response_model=ChatOut)
async def ai_chat(body: ChatIn, uid: str = Depends(get_current_user_id),
                  db: Session = Depends(get_db)):
    user = db.query(User).filter_by(id=uid).first()
    if not user:
        raise HTTPException(404, "User not found")

    if not user.is_premium:
        today = date.today()
        if user.last_ai_message_date != today:
            user.ai_messages_today = 0
            user.last_ai_message_date = today
        if (user.ai_messages_today or 0) >= 3:
            db.commit()
            raise HTTPException(
                status_code=403,
                detail=("Batas harian AI tercapai. Upgrade ke Premium untuk "
                        "akses tanpa batas."),
            )
        user.ai_messages_today = (user.ai_messages_today or 0) + 1
        user.last_ai_message_date = today

    ctx = build_context(db, uid)
    prompt = ("Konteks transaksi pengguna "
              "(date | type | amount | category | merchant | note):\n"
              f"{ctx}\n\n"
              f"Pertanyaan pengguna: {body.question}")
    answer = await ask_ai(prompt)
    db.add(Insight(user_id=uid, type="chat",
                   message=f"Q: {body.question[:500]}\nA: {answer[:2000]}"))
    db.commit()
    return ChatOut(answer=answer)


@router.post("/ai/parse-voice", response_model=VoiceParseOut)
async def parse_voice(body: VoiceParseIn,
                      uid: str = Depends(get_current_user_id)):
    """Turn a spoken transaction phrase into amount/merchant/category."""
    try:
        data = await parse_voice_transaction(body.text)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail="Gagal memproses input suara. Silakan coba lagi.",
        ) from exc
    return VoiceParseOut(**data)
