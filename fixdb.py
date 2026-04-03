from sqlalchemy import create_engine, text
import os

DATABASE_URL = 'postgresql://alumni_management_app_user:TTEvFTZzlBP0y7UNsSPgvQgEL1WBLxxC@dpg-d75pl394tr6s73cbu740-a.oregon-postgres.render.com/alumni_management_app'

if not DATABASE_URL:
    raise ValueError("DATABASE_URL not set")

engine = create_engine(DATABASE_URL)

def fix_otp_column():
    with engine.connect() as conn:
        print("🔍 Checking table existence...")

        # Check if table exists
        table_check = conn.execute(text("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables
                WHERE table_name = 'otp_store'
            );
        """)).scalar()

        if not table_check:
            print("❌ Table 'otp_store' does not exist")
            return

        print("✅ Table exists")

        # Check column existence and length
        print("🔍 Checking column info...")

        column_info = conn.execute(text("""
            SELECT data_type, character_maximum_length
            FROM information_schema.columns
            WHERE table_name = 'otp_store' AND column_name = 'otp';
        """)).fetchone()

        if not column_info:
            print("❌ Column 'otp' does not exist")
            return

        data_type, max_length = column_info

        print(f"ℹ️ Current type: {data_type}, length: {max_length}")

        # If already sufficient, skip
        if max_length is None or max_length >= 64:
            print("✅ Column already supports hashed OTP — no change needed")
            return

        print("⚠️ Column too small — updating...")

        # Alter column
        conn.execute(text("""
            ALTER TABLE otp_store
            ALTER COLUMN otp TYPE VARCHAR(128);
        """))

        conn.commit()

        print("✅ Column updated successfully!")


if __name__ == "__main__":
    fix_otp_column()