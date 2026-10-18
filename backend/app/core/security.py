"""Password hashing (bcrypt), JWT, Fernet token encryption."""
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from passlib.context import CryptContext
from cryptography.fernet import Fernet, InvalidToken
from app.core.config import settings

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

def _fernet() -> Fernet:
    key = settings.ENCRYPTION_KEY.strip() if settings.ENCRYPTION_KEY else ""
    if not key:
        # Dev fallback: deterministic key (DO NOT use in prod)
        key = Fernet.generate_key().decode()
    return Fernet(key.encode() if isinstance(key, str) else key)

_fernet_instance: Fernet | None = None

def fernet() -> Fernet:
    global _fernet_instance
    if _fernet_instance is None:
        _fernet_instance = _fernet()
    return _fernet_instance

def hash_password(pw: str) -> str:
    return pwd_ctx.hash(pw)

def verify_password(pw: str, hashed: str) -> bool:
    return pwd_ctx.verify(pw, hashed)

def create_access_token(sub: str, expires_min: int | None = None) -> str:
    exp = datetime.now(timezone.utc) + timedelta(
        minutes=expires_min or settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode({"sub": sub, "exp": exp},
                      settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)

def decode_token(token: str) -> str | None:
    try:
        payload = jwt.decode(token, settings.JWT_SECRET,
                             algorithms=[settings.JWT_ALGORITHM])
        return str(payload.get("sub"))
    except JWTError:
        return None

def encrypt_token(plain: str) -> str:
    return fernet().encrypt(plain.encode()).decode()

def decrypt_token(cipher: str) -> str:
    try:
        return fernet().decrypt(cipher.encode()).decode()
    except InvalidToken:
        return ""
