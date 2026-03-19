import random
import smtplib
import os
import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from email.mime.text import MIMEText
from jose import jwt

otp_store = {}
OTP_EXPIRY_MINUTES = int(os.getenv("OTP_EXPIRY_MINUTES", "5"))
PASSWORD_HASH_ITERATIONS = 390000

# JWT Configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-for-dev-only-change-this-in-prod")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 1 week for mobile session


def _utc_now():
    return datetime.now(timezone.utc)


def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    if expires_delta:
        expire = _utc_now() + expires_delta
    else:
        expire = _utc_now() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def generate_otp():
    return str(random.randint(100000, 999999))


def store_otp(email, otp):
    otp_store[email] = {
        "otp": otp,
        "expires_at": _utc_now() + timedelta(minutes=OTP_EXPIRY_MINUTES),
    }


def verify_stored_otp(email, otp):
    entry = otp_store.get(email)
    if not entry:
        return False
    if entry["expires_at"] < _utc_now():
        otp_store.pop(email, None)
        return False
    return entry["otp"] == otp


def clear_otp(email):
    otp_store.pop(email, None)


def send_email(email, otp):
    sender_email = os.getenv("SMTP_EMAIL")
    sender_password = os.getenv("SMTP_PASSWORD")

    if not sender_email or not sender_password:
        print(f"[DEV OTP] {email} -> {otp}")
        return

    msg = MIMEText(f"Your OTP is {otp}")
    msg["Subject"] = "OTP Verification"
    msg["From"] = sender_email
    msg["To"] = email

    server = smtplib.SMTP("smtp.gmail.com", 587)
    server.starttls()
    server.login(sender_email, sender_password)
    server.send_message(msg)
    server.quit()


def send_otp_email(email):
    otp = generate_otp()
    store_otp(email, otp)
    send_email(email, otp)
    return otp


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
