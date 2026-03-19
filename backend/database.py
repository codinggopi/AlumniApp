import os

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./alumni_app.db")

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
    seed_admin()
    ensure_schema_updates()


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
