"""FCM push via firebase-admin (graceful no-op when unconfigured)."""
import logging, os
log = logging.getLogger(__name__)

def send_push(user_id: str, title: str, body: str, data: dict | None = None) -> bool:
    cred = os.environ.get("FCM_CREDENTIALS_JSON", "./firebase-service-account.json")
    if not os.path.exists(cred):
        log.info("FCM skipped (no credentials): %s | %s", title, body)
        return False
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.Certificate(cred))
        # Topic per user; app subscribes to f"user_{user_id}"
        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            topic=f"user_{user_id}", data={k: str(v) for k, v in (data or {}).items()})
        messaging.send(msg)
        return True
    except Exception as e:  # never break budget writes
        log.warning("FCM failed: %s", e)
        return False
