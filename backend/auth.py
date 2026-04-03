import random
import smtplib
import os
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from jose import jwt

try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))
except ImportError:
    pass  # On Render, env vars are injected — dotenv not needed

OTP_EXPIRY_MINUTES = int(os.getenv("OTP_EXPIRY_MINUTES", "10"))
PASSWORD_HASH_ITERATIONS = 390000

# JWT Configuration
SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise ValueError("SECRET_KEY is not set in environment variables")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 1 week


def _utc_now():
    return datetime.now(timezone.utc)


def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    expire = _utc_now() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": int(expire.timestamp())})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def generate_otp():
    return str(secrets.randbelow(900000) + 100000)


# ── OTP Hashing ────────────────────────────────────────────────────────────

def _hash_otp(otp: str) -> str:
    return hashlib.sha256(otp.encode()).hexdigest()


# ── DB-backed OTP store ────────────────────────────────────────────────────

def store_otp(email: str, otp: str):
    try:
        from database import SessionLocal
        import models
    except ImportError:
        from .database import SessionLocal
        from . import models

    db = SessionLocal()
    try:
        expires_at = _utc_now() + timedelta(minutes=OTP_EXPIRY_MINUTES)
        hashed_otp = _hash_otp(otp)

        existing = db.query(models.OtpStore).filter(models.OtpStore.email == email).first()
        if existing:
            existing.otp = hashed_otp
            existing.expires_at = expires_at
        else:
            db.add(models.OtpStore(email=email, otp=hashed_otp, expires_at=expires_at))

        try:
            db.commit()
        except Exception:
            db.rollback()
            raise
    finally:
        db.close()


def verify_stored_otp(email: str, otp: str) -> bool:
    try:
        from database import SessionLocal
        import models
    except ImportError:
        from .database import SessionLocal
        from . import models

    db = SessionLocal()
    try:
        entry = db.query(models.OtpStore).filter(models.OtpStore.email == email).first()
        if not entry:
            return False

        expires = entry.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)

        if expires < _utc_now():
            db.delete(entry)
            db.commit()
            return False

        if entry.otp == _hash_otp(otp):
            db.delete(entry)  # prevent reuse
            db.commit()
            return True

        return False
    finally:
        db.close()


def clear_otp(email: str):
    try:
        from database import SessionLocal
        import models
    except ImportError:
        from .database import SessionLocal
        from . import models

    db = SessionLocal()
    try:
        db.query(models.OtpStore).filter(models.OtpStore.email == email).delete()
        db.commit()
    finally:
        db.close()


# ── Email ──────────────────────────────────────────────────────────────────

def send_email(email: str, otp: str, purpose: str = "reset"):
    sender_email = os.getenv("SMTP_EMAIL")
    sender_password = os.getenv("SMTP_PASSWORD")

    if os.getenv("ENV") == "dev":
        print(f"[OTP] {email} -> {otp} (purpose: {purpose})")
        print(f"[OTP] SMTP_EMAIL={'SET' if sender_email else 'NOT SET'}, SMTP_PASSWORD={'SET' if sender_password else 'NOT SET'}")

    if not sender_email or not sender_password:
        print("[OTP] SMTP not configured — OTP only printed above.")
        return

    from email.mime.multipart import MIMEMultipart
    from email.mime.text import MIMEText

    if purpose == "email_change":
        subject = "Verify Your New Email — Alumni Network"
        heading = "Email Address Change"
        body_text = "You requested to change your email address on Alumni Network App. Use the OTP below to confirm:"
        footer_note = "If you did not request this change, please secure your account immediately."
    else:
        subject = "Password Reset OTP — Alumni Network"
        heading = "Password Reset"
        body_text = "You requested a password reset on Alumni Network App. Use the OTP below to proceed:"
        footer_note = "If you did not request a password reset, ignore this email."

    html_body = f"""
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:32px;
                border:1px solid #e0e0e0;border-radius:12px;">
      <h2 style="color:#1565C0;margin-bottom:8px;">Alumni Network</h2>
      <h3 style="color:#333;margin-bottom:4px;">{heading}</h3>
      <p style="color:#555;font-size:15px;">{body_text}</p>
      <div style="background:#f0f4ff;border-radius:8px;padding:20px;text-align:center;margin:24px 0;">
        <span style="font-size:36px;font-weight:bold;letter-spacing:10px;color:#1565C0;">{otp}</span>
      </div>
      <p style="color:#666;font-size:13px;">
        This OTP expires in <strong>{OTP_EXPIRY_MINUTES} minutes</strong>.
      </p>
      <p style="color:#666;font-size:13px;">{footer_note}</p>
      <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
      <p style="color:#aaa;font-size:11px;text-align:center;">Alumni Network App</p>
    </div>
    """

    plain = f"{heading}\n\n{body_text}\n\nOTP: {otp}\n\nExpires in {OTP_EXPIRY_MINUTES} minutes.\n\n{footer_note}"
    print("body parsed ",plain)
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"Alumni Network App"
    msg["To"] = email

    msg.attach(MIMEText(plain, "plain"))
    msg.attach(MIMEText(html_body, "html"))
    print("msg parsed : ",msg)
    try:
        with smtplib.SMTP("smtp.gmail.com", 587) as server:
            server.starttls()
            print("attempt to start login")
            server.login(sender_email, sender_password)
            print("login scucess")
            server.send_message(msg)

        print(f"[OTP] Email sent successfully to {email}")

    except Exception as e:
        print(f"[OTP] Failed to send email to {email}: {e}")


def send_otp_email(email: str) -> str:
    otp = generate_otp()
    store_otp(email, otp)
    send_email(email, otp, purpose="reset")
    return otp


def send_otp_email_change(email: str) -> str:
    otp = generate_otp()
    store_otp(email, otp)
    send_email(email, otp, purpose="email_change")
    return otp


# ── Password hashing ───────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    derived = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        PASSWORD_HASH_ITERATIONS,
    ).hex()
    return f"{PASSWORD_HASH_ITERATIONS}${salt}${derived}"


def verify_password(password: str, stored_hash: str) -> bool:
    if not stored_hash:
        return False
    try:
        iterations_str, salt, expected_hash = stored_hash.split("$", 2)
        iterations = int(iterations_str)
    except ValueError:
        return False

    derived = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        iterations,
    ).hex()

    return hmac.compare_digest(derived, expected_hash)