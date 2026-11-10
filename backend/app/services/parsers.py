import re

# Shared receipt / m-banking text parsing (mirrors lib/core/receipt_parser.dart).

# Matches: Rp 50.000, IDR 50000, Rp50,000.00, $12.34, labelled nominal/total.
AMOUNT_RES = [
    re.compile(r"(?:Rp\.?|IDR)\s*([\d\.,]+)", re.IGNORECASE),
    re.compile(r"\$\s*([\d,]+\.?\d*)"),
    re.compile(
        r"(nominal(?:\s+transfer)?|jumlah(?:\s+transfer)?|total(?:\s+bayar)?|"
        r"grand\s+total|amount|nilai|transfer|debit|kredit|bayar|paid|"
        r"pembayaran|tagihan|diterima|masuk)"
        r"\s*[:\-]?\s*(?:Rp\.?|IDR|\$)?\s*([\d\.,]+)",
        re.IGNORECASE,
    ),
]

DATE_RES = [
    re.compile(r"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"),
    re.compile(r"\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b"),
    re.compile(r"\b(\d{1,2})[/-](\d{1,2})[/-](\d{2})\b"),
    re.compile(r"\b(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4})\b"),
]

MONTH_MAP = {
    "jan": 1, "januari": 1, "january": 1,
    "feb": 2, "februari": 2, "february": 2,
    "mar": 3, "maret": 3, "march": 3,
    "apr": 4, "april": 4,
    "mei": 5, "may": 5,
    "jun": 6, "juni": 6, "june": 6,
    "jul": 7, "juli": 7, "july": 7,
    "agu": 8, "agt": 8, "agustus": 8, "aug": 8, "august": 8,
    "sep": 9, "september": 9,
    "okt": 10, "oktober": 10, "oct": 10, "october": 10,
    "nov": 11, "november": 11,
    "des": 12, "desember": 12, "dec": 12, "december": 12,
}

MERCHANT_LABELS = [
    "ke rekening", "kepada", "penerima", "nama penerima", "merchant", "tujuan",
    "deskripsi", "description", "berita",
]

SKIP_MERCHANT = [
    "transfer berhasil", "transaksi berhasil", "pembayaran berhasil", "berhasil",
    "bukti transfer", "detail transaksi", "struk", "receipt", "m-banking",
    "mobile banking", "saldo", "nominal", "total", "tanggal", "waktu", "jam",
    "no. referensi", "referensi", "bca", "mandiri", "bri", "bni", "cimb",
    "permata", "danamon", "btpn", "jago", "seabank", "gopay", "ovo", "dana",
    "shopeepay", "linkaja",
]

BANK_KEYWORDS = [
    "transaction", "transaksi", "payment", "pembayaran", "debit", "credit",
    "transfer", "top up", "topup", "purchase", "qris", "e-money", "nominal",
    "transfer berhasil", "dana masuk", "dana keluar", "mutasi",
]


def _to_number(raw: str) -> float | None:
    s = raw.strip().replace(" ", "")
    if not s:
        return None
    if "," in s and "." in s:
        if s.rfind(",") > s.rfind("."):
            s = s.replace(".", "").replace(",", ".")
        else:
            s = s.replace(",", "")
    elif "," in s:
        parts = s.split(",")
        # Indonesian decimal comma only when the last group has 2 digits.
        s = (",".join(parts[:-1]) + "." + parts[-1]) if len(parts[-1]) == 2 else s.replace(",", "")
    elif re.fullmatch(r"\d{1,3}(\.\d{3})+", s):
        s = s.replace(".", "")
    try:
        return float(s)
    except ValueError:
        return None


def _amounts_in_line(line: str) -> list[float]:
    values: list[float] = []
    for rx in AMOUNT_RES:
        group = 2 if rx is AMOUNT_RES[2] else 1
        for m in rx.finditer(line):
            v = _to_number(m.group(group))
            if v is not None:
                values.append(v)
    return values


def _score_amount(context: str, line: str) -> int:
    t = context.lower()

    def has(keys: list[str]) -> bool:
        return any(k in t for k in keys)

    if has(["saldo", "balance", "sisa"]):
        return 5
    if has(["admin", "biaya", "fee", "ppn", "pajak", "tax"]):
        return 10
    if has(["nominal"]):
        return 100
    if has(["grand total"]):
        return 90
    if has(["total"]):
        return 85
    if has(["jumlah", "amount", "nilai", "transfer", "debit", "kredit", "bayar",
            "paid", "pembayaran", "tagihan", "diterima", "masuk"]):
        return 75
    if re.search(r"(?:Rp\.?|IDR|\$)", line, re.IGNORECASE):
        return 40
    return 20


def _pick_amount(text: str) -> float | None:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    best: tuple[float, int] | None = None  # (value, score)
    for i, line in enumerate(lines):
        values = _amounts_in_line(line)
        if not values:
            continue
        context = f"{lines[i - 1] if i > 0 else ''} {line}"
        score = _score_amount(context, line)
        for v in values:
            if v <= 0:
                continue
            if best is None or score > best[1] or (score == best[1] and v > best[0]):
                best = (v, score)
    return best[0] if best else None


def parse_amount(text: str) -> float | None:
    return _pick_amount(text)


def _iso_date(y: int, m: int, d: int) -> str | None:
    if m < 1 or m > 12 or d < 1 or d > 31:
        return None
    return f"{y:04d}-{m:02d}-{d:02d}"


def parse_date(text: str) -> str | None:
    m = DATE_RES[0].search(text)
    if m:
        return _iso_date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    m = DATE_RES[1].search(text)
    if m:
        return _iso_date(int(m.group(3)), int(m.group(2)), int(m.group(1)))
    m = DATE_RES[2].search(text)
    if m:
        return _iso_date(2000 + int(m.group(3)), int(m.group(2)), int(m.group(1)))
    m = DATE_RES[3].search(text)
    if m:
        month = MONTH_MAP.get(m.group(2).lower())
        if month:
            return _iso_date(int(m.group(3)), month, int(m.group(1)))
    return None


def detect_type(text: str) -> str:
    t = text.lower()
    income = [
        "transfer masuk", "dana masuk", "uang masuk", "diterima", "received",
        "kredit", "credit", "gaji", "salary", "refund", "pemasukan", "top up",
        "topup",
    ]
    expense = [
        "transfer keluar", "dana keluar", "debit", "pembayaran", "payment",
        "pembelian", "purchase", "qris", "bayar", "pengeluaran",
        "transfer berhasil",
    ]
    is_income = any(k in t for k in income)
    is_expense = any(k in t for k in expense)
    if is_income and not is_expense:
        return "income"
    return "expense"


def looks_like_bank_email(subject: str, body: str) -> bool:
    t = (subject + " " + body).lower()
    return any(k in t for k in BANK_KEYWORDS) and parse_amount(body) is not None


def _plausible_merchant(value: str) -> bool:
    t = value.strip()
    if len(t) < 2 or len(t) > 100:
        return False
    if _pick_amount(t) is not None or parse_date(t) is not None:
        return False
    lower = t.lower()
    if any(k in lower for k in SKIP_MERCHANT):
        return False
    if re.fullmatch(r"[\d\s\-+*/#.,:]+", t):
        return False
    return True


def _clean_merchant(value: str) -> str:
    return re.sub(r"[:\-]+$", "", re.sub(r"\s+", " ", value.strip())).strip()


def _value_after_label(line: str, labels: list[str]) -> str | None:
    lower = line.lower()
    for label in labels:
        idx = lower.find(label)
        if idx == -1:
            continue
        rest = line[idx + len(label):].strip()
        rest = re.sub(r"^[:\-–]\s*", "", rest).strip()
        if rest:
            return rest
    return None


def extract_merchant(lines: list[str]) -> str | None:
    for i, line in enumerate(lines):
        value = _value_after_label(line, MERCHANT_LABELS)
        if value is not None and _plausible_merchant(value):
            return _clean_merchant(value)
        if value is None and i + 1 < len(lines):
            lower = line.lower().strip()
            label_only = any(
                lower in (label, f"{label}:", f"{label} -") for label in MERCHANT_LABELS
            )
            if label_only and _plausible_merchant(lines[i + 1]):
                return _clean_merchant(lines[i + 1])
    for line in lines[:8]:
        if _plausible_merchant(line):
            return _clean_merchant(line)
    return None


def parse_receipt_text(full_text: str) -> dict:
    """Shared by docs + backend fallback. Returns merchant/total/date/type."""
    lines = [line for line in full_text.splitlines() if line.strip()]
    return {
        "merchant": extract_merchant(lines),
        "total": _pick_amount(full_text),
        "date": parse_date(full_text),
        "type": detect_type(full_text),
    }
