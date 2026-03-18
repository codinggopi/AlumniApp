import random
import smtplib
import os
from datetime import datetime, timedelta
from email.mime.text import MIMEText

otp_store = {}
OTP_EXPIRY_MINUTES = int(os.getenv("OTP_EXPIRY_MINUTES", "5"))


def _utc_now():
    return datetime.utcnow()


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
