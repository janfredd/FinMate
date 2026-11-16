from fastapi import APIRouter, Depends, HTTPException
from app.core.deps import get_current_user_id
from app.schemas.schemas import VoiceParseIn, VoiceParseOut
from app.services.ai_service import parse_voice_transaction

router = APIRouter()


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
