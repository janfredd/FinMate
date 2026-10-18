from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DATABASE_URL: str = "sqlite:///./finmate.db"
    JWT_SECRET: str = "dev-secret-change-me-32chars-minimum!!"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080
    ENCRYPTION_KEY: str = ""  # Fernet key; generated if empty (dev only)
    SUPABASE_URL: str = ""
    SUPABASE_KEY: str = ""
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    GOOGLE_REDIRECT_URI: str = "https://your-backend/oauth/gmail/callback"
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-1.5-flash"
    FCM_CREDENTIALS_JSON: str = "./firebase-service-account.json"
    FRONTEND_URL: str = "finmate://oauth/callback"
    CORS_ORIGINS: str = "*"

    class Config:
        env_file = ".env"

settings = Settings()
