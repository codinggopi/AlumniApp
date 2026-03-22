import hashlib, secrets, sqlite3

def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    iters = 390000
    derived = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), iters).hex()
    return f"{iters}${salt}${derived}"

conn = sqlite3.connect("alumni_app.db")
cursor = conn.cursor()
new_hash = hash_password("admin123")
cursor.execute("UPDATE users SET password_hash = ? WHERE email = 'admin@gmail.com'", (new_hash,))
conn.commit()
conn.close()
print("Admin password reset to 'admin123'")
