import os

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

# Supabase PostgreSQL connection string
# Replace the URL below with your Supabase connection string from:
# Supabase Dashboard → Settings → Database → Connection string → URI
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:[gopinathapp12344]@db.oxynqlrgwntkfoawxraj.supabase.co:5432/postgres"
)

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_database_url() -> str:
    return DATABASE_URL


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
