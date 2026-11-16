"""Groq (OpenAI-compatible) API call + proactive insight generation."""
import json
import re
from openai import (AsyncOpenAI, APIConnectionError, APIStatusError,
                    APITimeoutError, AuthenticationError, RateLimitError)
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import date, timedelta
from app.core.config import settings
from app.models.models import Transaction, Category, Insight

GROQ_BASE_URL = "https://api.groq.com/openai/v1"
GROQ_TIMEOUT = 60

SYSTEM_PROMPT = (
    "IDENTITAS DIRI: Kamu adalah FinMate, asisten keuangan pintar yang ada DI DALAM "
    "aplikasi FinMate. Kamu bukan chatbot terpisah dan bukan aplikasi lain. "
    "JANGAN pernah menyarankan pengguna memakai aplikasi lain, spreadsheet, buku catatan, "
    "atau mencatat manual di luar FinMate. Kalau pengguna butuh mencatat, mengatur budget, "
    "atau melihat riwayat, arahkan mereka ke fitur yang ada di FinMate ini, misalnya: "
    "'Coba atur budget harianmu di menu Budget FinMate' atau 'Catat pengeluaranmu di sini "
    "biar aku bisa bantu analisa'. "
    "Menu yang tersedia di FinMate: Dashboard (ringkasan keuangan), Transactions "
    "(catat dan lihat transaksi), Budget, AI Assistant, dan Profile. Sebut nama menu "
    "persis seperti itu, jangan mengarang nama menu lain. "
    "PERSONA: Pakai gaya 'aku-kamu' yang santai, suportif, solutif, dan natural seperti "
    "teman ngobrol. Boleh sedikit Gen Z dengan kata seperti 'biar', 'banget', atau 'nih' "
    "secukupnya, tapi jangan berlebihan atau alay. Jangan mulai dengan basa-basi klise "
    "seperti 'Tentu!', 'Sebagai AI', atau 'Pertanyaan yang bagus'. Jawab langsung ke inti "
    "di kalimat pertama, lalu jelaskan singkat. "
    "FORMAT TEKS: DILARANG KERAS memakai simbol markdown seperti **, *, #, _, atau tabel. "
    "Antarmuka aplikasi tidak mendukung format markdown. Cukup pakai teks biasa, spasi, "
    "enter untuk paragraf baru, dan simbol bullet biasa '•' kalau ada beberapa poin. "
    "Tulis nominal dengan format Rp dan pemisah ribuan (contoh: Rp1.250.000). "
    "Buat jawaban mudah dibaca: paragraf pendek (maksimal 3 baris), cukup 3-5 poin atau "
    "3-4 paragraf, jangan bertele-tele. Emoji maksimal 1-2 dan hanya kalau terasa natural. "
    "Gunakan hanya data dari konteks transaksi; jangan mengarang angka atau transaksi. "
    "Kalau data belum ada, bilang jujur dengan santai dan sarankan fitur FinMate yang "
    "bisa dipakai. Akhiri dengan satu saran praktis atau pertanyaan lanjutan."
)


def _clean_output(text: str) -> str:
    """Strip markdown so Flutter's plain Text widget stays readable."""
    text = re.sub(r"```[a-zA-Z]*", "", text)
    text = text.replace("`", "")
    text = re.sub(r"^\s*#{1,6}\s*", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*[-*+]\s+", "• ", text, flags=re.MULTILINE)
    text = re.sub(r"\[(.+?)\]\((.+?)\)", r"\1 (\2)", text)
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text, flags=re.DOTALL)
    text = re.sub(r"__(.+?)__", r"\1", text, flags=re.DOTALL)
    text = re.sub(r"(?<!\w)_(.+?)_(?!\w)", r"\1", text)
    text = re.sub(r"\*(.+?)\*", r"\1", text)
    text = text.replace("*", "")
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _build_client() -> AsyncOpenAI:
    return AsyncOpenAI(
        api_key=settings.GROQ_API_KEY,
        base_url=GROQ_BASE_URL,
        timeout=GROQ_TIMEOUT,
    )


async def ask_ai(prompt: str) -> str:
    if not settings.GROQ_API_KEY:
        return ("Maaf, layanan AI belum dikonfigurasi. "
                "Silakan hubungi admin untuk mengatur GROQ_API_KEY.")

    try:
        client = _build_client()
        completion = await client.chat.completions.create(
            model=settings.GROQ_MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
            temperature=0.7,
            max_tokens=1024,
        )

        choices = getattr(completion, "choices", None) or []
        if not choices:
            return "Maaf, AI tidak memberikan respons. Silakan coba lagi."

        text = (choices[0].message.content or "").strip()
        if not text:
            return "Maaf, AI memberikan respons kosong. Silakan coba lagi."
        return _clean_output(text)

    except AuthenticationError:
        return ("Maaf, kunci API Groq tidak valid. "
                "Silakan periksa kembali konfigurasi GROQ_API_KEY.")
    except RateLimitError:
        return ("Maaf, kuota penggunaan AI sedang penuh atau batas permintaan "
                "terlampaui. Silakan coba beberapa saat lagi.")
    except APITimeoutError:
        return (f"Maaf, permintaan ke layanan AI timeout setelah {GROQ_TIMEOUT} detik. "
                "Silakan coba lagi.")
    except APIConnectionError:
        return ("Maaf, gagal terhubung ke layanan AI Groq. "
                "Periksa koneksi internet dan coba lagi.")
    except APIStatusError as e:
        if e.status_code == 404:
            return (f"Maaf, model AI '{settings.GROQ_MODEL}' tidak tersedia. "
                    "Silakan periksa konfigurasi GROQ_MODEL.")
        return (f"Maaf, layanan AI sedang bermasalah (status {e.status_code}). "
                "Silakan coba lagi nanti.")
    except Exception:
        return ("Maaf, terjadi kesalahan tak terduga saat memproses permintaan AI. "
                "Silakan coba lagi nanti.")


VOICE_SYSTEM_PROMPT = (
    "Kamu adalah parser transaksi. Ekstrak teks berikut menjadi format JSON "
    "dengan key: amount (angka saja), merchant (string), dan category (string, "
    "pilih dari: Food, Transportation, Shopping, Entertainment, Bills, Health, "
    "Education, Others). Hanya kembalikan JSON murni tanpa markdown."
)
VALID_CATEGORIES = ("Food", "Transportation", "Shopping", "Entertainment",
                    "Bills", "Health", "Education", "Others")


def _parse_amount(value: object) -> float:
    """Normalise numbers like '50.000', 'Rp 50.000', or 50000 into a float."""
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return max(0.0, float(value))
    raw = str(value or "").strip().lower()
    raw = raw.replace("rp", "").replace("idr", "")
    raw = re.sub(r"[^0-9,.\-]", "", raw)
    if not raw:
        return 0.0
    if "," in raw and "." in raw:
        raw = raw.replace(".", "").replace(",", ".")
    elif "," in raw:
        raw = raw.replace(",", ".")
    elif raw.count(".") > 1 or (
            raw.count(".") == 1 and len(raw.split(".")[-1]) == 3):
        raw = raw.replace(".", "")
    try:
        return max(0.0, float(raw))
    except ValueError:
        return 0.0


def _extract_json_object(text: str) -> dict:
    """Pull the first JSON object out of a model reply, fenced or not."""
    cleaned = re.sub(r"```(?:json)?", "", text or "")
    cleaned = cleaned.replace("`", "").strip()
    start, end = cleaned.find("{"), cleaned.rfind("}")
    if start == -1 or end <= start:
        raise ValueError("Parser AI tidak mengembalikan JSON yang valid.")
    data = json.loads(cleaned[start:end + 1])
    if not isinstance(data, dict):
        raise ValueError("Parser AI tidak mengembalikan objek JSON.")
    return data


async def parse_voice_transaction(text: str) -> dict:
    """Extract {amount, merchant, category} from a spoken transaction phrase."""
    if not settings.GROQ_API_KEY:
        raise ValueError("Layanan AI belum dikonfigurasi (GROQ_API_KEY kosong).")

    client = _build_client()
    completion = await client.chat.completions.create(
        model=settings.GROQ_MODEL,
        messages=[
            {"role": "system", "content": VOICE_SYSTEM_PROMPT},
            {"role": "user", "content": text},
        ],
        temperature=0,
        max_tokens=256,
    )
    choices = getattr(completion, "choices", None) or []
    if not choices:
        raise ValueError("AI tidak memberikan respons.")
    data = _extract_json_object(choices[0].message.content or "")

    amount = _parse_amount(data.get("amount", 0))
    merchant = str(data.get("merchant") or "").strip() or "Unknown"
    category = str(data.get("category") or "").strip()
    matched = next((c for c in VALID_CATEGORIES
                    if c.lower() == category.lower()), "Others")
    return {"amount": amount, "merchant": merchant, "category": matched}


def build_context(db: Session, user_id: str, limit: int = 100) -> str:
    txns = (db.query(Transaction).filter(Transaction.user_id == user_id)
            .order_by(Transaction.date.desc()).limit(limit).all())
    if not txns:
        return "Belum ada transaksi yang tercatat."
    cat = {c.id: c.name for c in db.query(Category).all()}
    lines = []
    for t in txns:
        lines.append(f"{t.date} | {t.type} | {float(t.amount):.2f} | "
                     f"{cat.get(t.category_id, '-')} | {t.merchant or '-'} | {t.note or ''}")
    return "\n".join(lines)


def _format_rupiah(value: float) -> str:
    return "Rp" + f"{float(value):,.0f}".replace(",", ".")


def generate_proactive_insights(db: Session, user_id: str) -> list[str]:
    """Rule-based: spikes per category vs previous 30d, budget-free saving tips."""
    today = date.today()
    cur_start, prev_start = today - timedelta(days=30), today - timedelta(days=60)
    msgs: list[str] = []
    cats = db.query(Category).all()
    cat_name = {c.id: c.name for c in cats}
    for cid, name in cat_name.items():
        cur = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter(
            Transaction.user_id == user_id, Transaction.type == "expense",
            Transaction.category_id == cid,
            Transaction.date >= cur_start).scalar() or 0
        prev = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter(
            Transaction.user_id == user_id, Transaction.type == "expense",
            Transaction.category_id == cid,
            Transaction.date >= prev_start, Transaction.date < cur_start).scalar() or 0
        if prev > 0 and cur > prev * 1.5:
            pct = (cur - prev) / prev * 100
            msgs.append(
                f"Pengeluaran {name} kamu naik {pct:.0f}% dalam 30 hari terakhir "
                f"(dari {_format_rupiah(prev)} jadi {_format_rupiah(cur)}). "
                "Mungkin ada yang perlu dicek lagi, ya."
            )
    total = db.query(func.coalesce(func.sum(Transaction.amount), 0)).filter(
        Transaction.user_id == user_id, Transaction.type == "expense",
        Transaction.date >= cur_start).scalar() or 0
    if total > 0:
        top = (db.query(Transaction.category_id, func.sum(Transaction.amount).label("s"))
               .filter(Transaction.user_id == user_id, Transaction.type == "expense",
                       Transaction.date >= cur_start)
               .group_by(Transaction.category_id).order_by(func.sum(Transaction.amount).desc())
               .first())
        if top and top[1]:
            name = cat_name.get(top[0], "kategori ini")
            msgs.append(
                f"Kategori paling besar kamu bulan ini adalah {name} "
                f"({_format_rupiah(top[1])}). Kalau kamu potong 10% saja, "
                f"kamu bisa hemat sekitar {_format_rupiah(float(top[1]) * 0.1)} "
                "bulan depan."
            )
    for m in msgs:
        db.add(Insight(user_id=user_id, type="proactive", message=m))
    db.commit()
    return msgs