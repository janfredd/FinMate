import re
from datetime import date

# Matches: Rp 50.000, IDR 50000, Rp50,000.00, $12.34, 50000
AMOUNT_RES = [
    re.compile(r"(?:Rp|IDR|Rs\.?)\s*([\d\.,]+)", re.IGNORECASE),
    re.compile(r"\$\s*([\d,]+\.?\d*)"),
    re.compile(r"(?:total|amount|grand total|bayar|paid)\s*[:\-]?\s*(?:Rp|IDR)?\s*([\d\.,]+)", re.IGNORECASE),
]

DATE_RES = [
    re.compile(r"(\d{4}-\d{2}-\d{2})"),
    re.compile(r"(\d{2}[/-]\d{2}[/-]\d{4})"),
    re.compile(r"(\d{2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})", re.IGNORECASE),
]

BANK_KEYWORDS = ["transaction", "transaksi", "payment", "pembayaran", "debit",
                 "credit", "transfer", "top up", "topup", "purchase", "qris", "e-money"]

def parse_amount(text: str) -> float | None:
    for rx in AMOUNT_RES:
        m = rx.search(text)
        if m:
            raw = m.group(1).replace(" ", "")
            # Heuristic: Indonesian format 50.000,00 -> 50000.00
            if "," in raw and "." in raw:
                if raw.rfind(",") > raw.rfind("."):
                    raw = raw.replace(".", "").replace(",", ".")
                else:
                    raw = raw.replace(",", "")
            elif "," in raw and "." not in raw:
                parts = raw.split(",")
                raw = raw.replace(",", "." if len(parts[-1]) == 2 else "")
            else:
                raw = raw.replace(",", "")
                # "50.000" -> 50000 when 3-digit groups
                if re.fullmatch(r"\d{1,3}(\.\d{3})+", raw):
                    raw = raw.replace(".", "")
            try:
                return float(raw)
            except ValueError:
                continue
    return None

def parse_date(text: str) -> str | None:
    for rx in DATE_RES:
        m = rx.search(text)
        if m:
            return m.group(1)
    return None

def detect_type(text: str) -> str:
    t = text.lower()
    if any(k in t for k in ["credit", "incoming", "received", "diterima", "masuk", "salary", "gaji", "refund"]):
        return "income"
    return "expense"

def looks_like_bank_email(subject: str, body: str) -> bool:
    t = (subject + " " + body).lower()
    return any(k in t for k in BANK_KEYWORDS) and parse_amount(body) is not None

def extract_merchant(lines: list[str]) -> str | None:
    for line in lines[:5]:
        s = line.strip()
        if len(s) > 2 and parse_amount(s) is None and parse_date(s) is None:
            if not re.match(r"^[*#\-=\s]+$", s):
                return s[:100]
    return None

def parse_receipt_text(full_text: str) -> dict:
    """Shared by docs + backend fallback. Returns merchant/total/date."""
    lines = [l for l in full_text.splitlines() if l.strip()]
    amounts = []
    for line in lines:
        a = parse_amount(line)
        if a:
            amounts.append(a)
    return {
        "merchant": extract_merchant(lines),
        "total": max(amounts) if amounts else None,
        "date": parse_date(full_text),
    }
