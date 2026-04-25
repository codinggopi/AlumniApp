import os
from typing import Optional

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker


def normalize_database_url(raw_url: Optional[str]) -> str:
    if not raw_url:
        return "sqlite:///./alumni_app.db"

    # Some hosting providers expose postgres://; SQLAlchemy expects postgresql://
    if raw_url.startswith("postgres://"):
        return raw_url.replace("postgres://", "postgresql://", 1)

    return raw_url


DATABASE_URL = normalize_database_url(os.getenv("DATABASE_URL"))

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_database_url() -> str:
    return DATABASE_URL


if os.getenv("RENDER") and DATABASE_URL.startswith("sqlite"):
    print(
        "Warning: Running on Render with SQLite fallback. "
        "Data may reset on restart/redeploy. Configure DATABASE_URL to a persistent PostgreSQL database."
    )


def get_session():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    try:
        from . import models
    except (ImportError, ValueError):
        import models

    models.Base.metadata.create_all(bind=engine)
    ensure_schema_updates()
    seed_admin()


def seed_admin():
    try:
        from . import models, auth
    except (ImportError, ValueError):
        import models
        import auth
    db = SessionLocal()
    try:
        admin_email = "admin@gmail.com"
        existing = db.query(models.User).filter(models.User.email == admin_email).first()
        if not existing:
            admin_user = models.User(
                email=admin_email,
                full_name="Administrator",
                password_hash=auth.hash_password("admin123"),
                role="admin",
                is_verified=True
            )
            db.add(admin_user)
            db.commit()
            print(f"Seeded default admin: {admin_email}")
    finally:
        db.close()


def ensure_schema_updates():
    inspector = inspect(engine)

    if "users" not in inspector.get_table_names():
        return

    user_columns = {column["name"] for column in inspector.get_columns("users")}
    if "password_hash" not in user_columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE users ADD COLUMN password_hash VARCHAR(255)"))

    if "profile_picture_url" not in user_columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE users ADD COLUMN profile_picture_url VARCHAR(255)"))

    if "current_status" not in user_columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE users ADD COLUMN current_status VARCHAR(200)"))

    if "designation" not in user_columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE users ADD COLUMN designation VARCHAR(120)"))

    if "responsibilities" not in user_columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE users ADD COLUMN responsibilities TEXT"))

    if "fcm_token" not in user_columns:
        with engine.begin() as connection:
            connection.execute(text("ALTER TABLE users ADD COLUMN fcm_token VARCHAR(255)"))

    if "events" in inspector.get_table_names():
        event_columns = {column["name"] for column in inspector.get_columns("events")}
        
        if "category" not in event_columns:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE events ADD COLUMN category VARCHAR(50) DEFAULT 'event' NOT NULL"))

        if "target_audience" not in event_columns:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE events ADD COLUMN target_audience VARCHAR(50) DEFAULT 'all' NOT NULL"))

        if "has_document" not in event_columns:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE events ADD COLUMN has_document BOOLEAN DEFAULT 0 NOT NULL"))

        if "has_photos" not in event_columns:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE events ADD COLUMN has_photos BOOLEAN DEFAULT 0 NOT NULL"))

        if "document_url" not in event_columns:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE events ADD COLUMN document_url VARCHAR(255)"))

        if "photo_url" not in event_columns:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE events ADD COLUMN photo_url VARCHAR(255)"))

    if "student_profiles" in inspector.get_table_names():
        st_cols = {c["name"] for c in inspector.get_columns("student_profiles")}
        if "educational_details" not in st_cols:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE student_profiles ADD COLUMN educational_details TEXT"))

    if "messages" in inspector.get_table_names():
        msg_cols = {c["name"] for c in inspector.get_columns("messages")}
        if "is_read" not in msg_cols:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE messages ADD COLUMN is_read BOOLEAN DEFAULT 0 NOT NULL"))

    # MentorshipSlot: add meeting_link column if missing
    if "mentorship_slots" in inspector.get_table_names():
        slot_cols = {c["name"] for c in inspector.get_columns("mentorship_slots")}
        if "meeting_link" not in slot_cols:
            with engine.begin() as connection:
                connection.execute(text("ALTER TABLE mentorship_slots ADD COLUMN meeting_link VARCHAR(500)"))

    # Feedback table migration: old schema had alumni_id, new schema uses target_id + target_role + admin_response
    if "feedback" in inspector.get_table_names():
        fb_cols = {c["name"] for c in inspector.get_columns("feedback")}
        if "target_id" not in fb_cols:
            # Recreate the table with the new schema (SQLite doesn't support DROP COLUMN)
            with engine.begin() as connection:
                connection.execute(text("DROP TABLE feedback"))
            # Let create_all recreate it with the new schema
            try:
                from . import models
            except (ImportError, ValueError):
                import models
            models.Base.metadata.tables["feedback"].create(bind=engine)
        else:
            if "target_role" not in fb_cols:
                with engine.begin() as connection:
                    connection.execute(text("ALTER TABLE feedback ADD COLUMN target_role VARCHAR(20) NOT NULL DEFAULT 'alumni'"))
            if "admin_response" not in fb_cols:
                with engine.begin() as connection:
                    connection.execute(text("ALTER TABLE feedback ADD COLUMN admin_response TEXT"))
