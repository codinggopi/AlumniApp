import os
import shutil
from datetime import datetime, timezone, timedelta
from typing import Optional
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))
except ImportError:
    pass  # On Render, env vars are injected — dotenv not needed
from fastapi import Depends, FastAPI, File, HTTPException, UploadFile, status, Body
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy.orm import Session

try:
    from .auth import ALGORITHM, SECRET_KEY, clear_otp, create_access_token, hash_password, send_otp_email, send_otp_email_change, verify_password, verify_stored_otp
    from .database import get_session, init_db
    from . import models
except ImportError:
    from auth import ALGORITHM, SECRET_KEY, clear_otp, create_access_token, hash_password, send_otp_email, send_otp_email_change, verify_password, verify_stored_otp
    from database import get_session, init_db
    import models
from jose import JWTError, jwt


init_db()

tags_metadata = [
    {"name": "auth", "description": "Operations with user authentication and registration."},
    {"name": "profile", "description": "Manage user profiles and resumes."},
    {"name": "alumni", "description": "Explore the alumni network directory."},
    {"name": "internships", "description": "Browse and post internship opportunities."},
    {"name": "applications", "description": "Track and manage internship applications."},
    {"name": "messages", "description": "One-to-one communication between members."},
    {"name": "events", "description": "Platform-wide events and announcements."},
]

app = FastAPI(
    title="Alumni-Student Network API",
    description="Backend API for the Alumni-Student Networking Platform v2.0. Supports JWT authentication, real-time messaging, and internship management.",
    version="2.0.0",
    openapi_tags=tags_metadata,
)
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "*",
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8000",
        "http://localhost:8080",
        "http://localhost:52000",
        "http://localhost:53000",
        "http://localhost:54000",
        "http://127.0.0.1:8000",
    ],
    allow_origin_regex=r"https://.*\.ngrok.*|http://localhost:.*|http://127\.0\.0\.1:.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")


class SendOtpRequest(BaseModel):
    email: str


class VerifyOtpRequest(BaseModel):
    email: str
    otp: str
    full_name: str
    role: str
    phone: Optional[str] = None
    department: Optional[str] = None
    graduation_year: Optional[int] = None
    city: Optional[str] = None
    bio: Optional[str] = None
    company: Optional[str] = None
    job_title: Optional[str] = None
    mentorship_available: bool = True
    skills: Optional[str] = None
    interests: Optional[str] = None
    resume_url: Optional[str] = None


class InternshipCreate(BaseModel):
    posted_by: int
    role_title: str
    company: str
    location: Optional[str] = None
    duration: Optional[str] = None
    stipend: Optional[str] = None
    required_skills: Optional[str] = None
    seats: int = 1
    deadline: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = "Open"


class ApplicationCreate(BaseModel):
    internship_id: int
    student_id: int
    cover_note: Optional[str] = None
    resume_url: Optional[str] = None


class ApplicationStatusUpdate(BaseModel):
    status: str


class EventCreate(BaseModel):
    created_by: int
    title: str
    date: Optional[str] = None
    location: Optional[str] = None
    description: Optional[str] = None
    category: str = "event"
    target_audience: str = "all"  # "all", "student", "alumni"
    has_document: bool = False
    has_photos: bool = False
    document_url: Optional[str] = None
    photo_url: Optional[str] = None


class AnnouncementCreate(BaseModel):
    created_by: int
    title: str
    content: str


class ConnectionCreate(BaseModel):
    requester_id: int
    receiver_id: int


class ConnectionStatusUpdate(BaseModel):
    status: str


class ResourceCreate(BaseModel):
    created_by: int
    title: str
    description: Optional[str] = None
    resource_type: str  # 'document', 'link'
    url: str
    target_audience: str = "all"  # "all", "student", "alumni"


class NotificationCreate(BaseModel):
    user_id: int
    type: Optional[str] = None
    message: str


class MessageCreate(BaseModel):
    sender_id: int
    receiver_id: int
    content: str


class AuthRegisterRequest(BaseModel):
    email: str
    password: str
    full_name: str
    role: str


class AuthLoginRequest(BaseModel):
    email: str
    password: str
    role: str


class ResetPasswordRequest(BaseModel):
    email: str
    role: str
    otp: str
    new_password: str


class ProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    department: Optional[str] = None
    graduation_year: Optional[int] = None
    city: Optional[str] = None
    bio: Optional[str] = None
    company: Optional[str] = None
    job_title: Optional[str] = None
    mentorship_available: Optional[bool] = None
    skills: Optional[str] = None
    interests: Optional[str] = None
    resume_url: Optional[str] = None
    experience_summary: Optional[str] = None
    profile_picture_url: Optional[str] = None
    current_status: Optional[str] = None
    designation: Optional[str] = None
    responsibilities: Optional[str] = None
    educational_details: Optional[str] = None
    skills: Optional[str] = None
    interests: Optional[str] = None
    resume_url: Optional[str] = None


def payload_dict(payload: BaseModel):
    return payload.model_dump() if hasattr(payload, "model_dump") else payload.dict()


def ensure_role(role: str, allowed_roles: set[str]):
    normalized = role.lower()
    if normalized not in allowed_roles:
        raise HTTPException(status_code=400, detail=f"Role must be one of: {', '.join(sorted(allowed_roles))}")
    return normalized


def get_db():
    yield from get_session()


def get_user_by_id(db: Session, user_id: int):
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def get_internship_by_id(db: Session, internship_id: int):
    internship = db.query(models.Internship).filter(models.Internship.internship_id == internship_id).first()
    if not internship:
        raise HTTPException(status_code=404, detail="Internship not found")
    return internship


def get_application_by_id(db: Session, application_id: int):
    application = db.query(models.Application).filter(models.Application.application_id == application_id).first()
    if not application:
        raise HTTPException(status_code=404, detail="Application not found")
    return application


def get_announcement_by_id(db: Session, announcement_id: int):
    announcement = db.query(models.Announcement).filter(models.Announcement.announcement_id == announcement_id).first()
    if not announcement:
        raise HTTPException(status_code=404, detail="Announcement not found")
    return announcement


def get_notification_by_id(db: Session, noti_id: int):
    notification = db.query(models.Notification).filter(models.Notification.noti_id == noti_id).first()
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    return notification


def get_connection_by_id(db: Session, connection_id: int):
    connection = db.query(models.Connection).filter(models.Connection.connection_id == connection_id).first()
    if not connection:
        raise HTTPException(status_code=404, detail="Connection not found")
    return connection


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_session)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = db.query(models.User).filter(models.User.user_id == int(user_id)).first()
    if user is None:
        raise credentials_exception
    return user


def _notify_audience(db, target_role: str, sender_id: int, noti_type: str, message: str):
    """Create a Notification row for every user matching target_role, excluding the sender."""
    query = db.query(models.User)
    if target_role != "all":
        query = query.filter(models.User.role == target_role)
    else:
        # "all" means students + alumni (not admin/staff themselves)
        query = query.filter(models.User.role.in_(["student", "alumni"]))

    for user in query.all():
        if user.user_id == sender_id:
            continue
        db.add(models.Notification(
            user_id=user.user_id,
            type=noti_type,
            message=message,
            is_read=False,
        ))
    db.commit()


def serialize_user(user: models.User):    return {
        "user_id": user.user_id,
        "email": user.email,
        "full_name": user.full_name,
        "role": user.role,
        "phone": user.phone,
        "department": user.department,
        "graduation_year": user.graduation_year,
        "city": user.city,
        "bio": user.bio,
        "profile_picture_url": user.profile_picture_url,
        "current_status": user.current_status,
        "designation": user.designation,
        "responsibilities": user.responsibilities,
        "is_verified": user.is_verified,
    }


def serialize_alumni(user: models.User, profile: models.AlumniProfile):
    data = serialize_user(user)
    data.update(
        {
            "company": profile.company,
            "job_title": profile.job_title,
            "mentorship_available": profile.mentorship_available,
            "experience_summary": profile.experience_summary,
        }
    )
    return data


def serialize_student(user: models.User, profile: models.StudentProfile):
    data = serialize_user(user)
    data.update(
        {
            "skills": profile.educational_details,
            "interests": profile.interests,
            "resume_url": profile.resume_url,
            "educational_details": profile.educational_details,
        }
    )
    return data


def ensure_connected(db: Session, sender_id: int, receiver_id: int):
    if sender_id == receiver_id:
        return None

    sender = get_user_by_id(db, sender_id)
    receiver = get_user_by_id(db, receiver_id)

    # Only gate student <-> alumni chats. Other role combinations keep current behavior.
    roles = {sender.role, receiver.role}
    if roles != {"student", "alumni"}:
        return None

    connection = db.query(models.Connection).filter(
        (
            (models.Connection.requester_id == sender_id)
            & (models.Connection.receiver_id == receiver_id)
        )
        | (
            (models.Connection.requester_id == receiver_id)
            & (models.Connection.receiver_id == sender_id)
        )
    ).filter(models.Connection.status == "accepted").first()

    if not connection:
        raise HTTPException(
            status_code=403,
            detail="Messaging is available only after the alumni accepts the connection request",
        )

    return None


@app.get("/")
def home():
    return {
        "message": "Alumni App backend running",
        "modules": ["auth", "directory", "internships", "applications", "events"],
    }


@app.post("/send-otp", tags=["auth"])
def send_otp(payload: SendOtpRequest):
    send_otp_email(payload.email)
    return {"message": "OTP sent", "expires_in_minutes": 5}


@app.post("/auth/register", tags=["auth"])
def register_with_password(payload: AuthRegisterRequest, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only admins can register new users")
    
    role = ensure_role(payload.role, {"student", "alumni", "admin", "staff"})

    existing_user = db.query(models.User).filter(models.User.email == payload.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="User already exists with this email")

    user = models.User(
        email=payload.email,
        full_name=payload.full_name,
        role=role,
        password_hash=hash_password(payload.password),
        is_verified=True,
    )
    db.add(user)
    db.flush()

    if role == "student":
        db.add(models.StudentProfile(student_id=user.user_id))
    if role == "alumni":
        db.add(models.AlumniProfile(alumni_id=user.user_id))

    db.commit()
    db.refresh(user)

    return {
        "status": "registered",
        "user_id": user.user_id,
        "email": user.email,
        "full_name": user.full_name,
        "role": user.role,
    }


@app.post("/auth/bulk-register", tags=["auth"])
async def bulk_register(
    file: UploadFile = File(...),
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Upload a CSV or Excel file to bulk register students/alumni.
    Required columns: full_name, email, password, role
    Optional columns: phone, department, graduation_year, city, company, job_title
    """
    import io
    import csv

    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only admins can bulk register users")

    content = await file.read()
    filename = file.filename.lower()

    rows = []

    if filename.endswith(".csv"):
        decoded = content.decode("utf-8-sig")
        reader = csv.DictReader(io.StringIO(decoded))
        rows = list(reader)
    elif filename.endswith(".xlsx") or filename.endswith(".xls"):
        try:
            import openpyxl
            wb = openpyxl.load_workbook(io.BytesIO(content))
            ws = wb.active
            headers = [cell.value for cell in ws[1]]
            for row in ws.iter_rows(min_row=2, values_only=True):
                rows.append(dict(zip(headers, row)))
        except ImportError:
            raise HTTPException(status_code=400, detail="openpyxl not installed. Use CSV format instead.")
    else:
        raise HTTPException(status_code=400, detail="Only .csv, .xlsx, or .xls files are supported")

    required_cols = {"full_name", "email", "password", "role"}
    if rows and not required_cols.issubset(set(rows[0].keys())):
        raise HTTPException(
            status_code=400,
            detail=f"Missing required columns. Need: {', '.join(required_cols)}"
        )

    results = {"success": [], "skipped": [], "errors": []}

    for i, row in enumerate(rows, start=2):
        try:
            email = str(row.get("email", "")).strip()
            full_name = str(row.get("full_name", "")).strip()
            password = str(row.get("password", "")).strip()
            role = str(row.get("role", "")).strip().lower()

            if not email or not full_name or not password or not role:
                results["errors"].append({"row": i, "reason": "Missing required field"})
                continue

            if role not in {"student", "alumni", "staff"}:
                results["errors"].append({"row": i, "email": email, "reason": f"Invalid role '{role}'"})
                continue

            existing = db.query(models.User).filter(models.User.email == email).first()
            if existing:
                results["skipped"].append({"row": i, "email": email, "reason": "Email already exists"})
                continue

            user = models.User(
                email=email,
                full_name=full_name,
                role=role,
                password_hash=hash_password(password),
                is_verified=True,
                phone=str(row.get("phone", "") or "").strip() or None,
                department=str(row.get("department", "") or "").strip() or None,
                graduation_year=int(row["graduation_year"]) if row.get("graduation_year") else None,
                city=str(row.get("city", "") or "").strip() or None,
            )
            db.add(user)
            db.flush()

            if role == "student":
                db.add(models.StudentProfile(student_id=user.user_id))
            if role == "alumni":
                profile = models.AlumniProfile(alumni_id=user.user_id)
                profile.company = str(row.get("company", "") or "").strip() or None
                profile.job_title = str(row.get("job_title", "") or "").strip() or None
                db.add(profile)

            db.commit()
            results["success"].append({"row": i, "email": email, "role": role})

        except Exception as e:
            db.rollback()
            results["errors"].append({"row": i, "reason": str(e)})

    return {
        "total": len(rows),
        "registered": len(results["success"]),
        "skipped": len(results["skipped"]),
        "errors": len(results["errors"]),
        "details": results,
    }


@app.post("/auth/login", tags=["auth"])
def login_with_password(payload: AuthLoginRequest, db: Session = Depends(get_db)):
    role = ensure_role(payload.role, {"student", "alumni", "admin", "staff"})
    user = db.query(models.User).filter(
        models.User.email == payload.email,
        models.User.role == role,
    ).first()

    if not user:
        print(f"Login failed: User '{payload.email}' with role '{role}' not found.")
        raise HTTPException(status_code=401, detail="Invalid email, role, or password")

    if not verify_password(payload.password, user.password_hash):
        print(f"Login failed: Incorrect password for '{payload.email}'.")
        raise HTTPException(status_code=401, detail="Invalid email, role, or password")

    access_token = create_access_token(data={"sub": str(user.user_id), "role": user.role})

    return {
        "status": "authenticated",
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user.user_id,
        "email": user.email,
        "full_name": user.full_name,
        "role": user.role,
    }


@app.post("/auth/reset-password", tags=["auth"])
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    if not verify_stored_otp(payload.email, payload.otp):
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")
    
    role = ensure_role(payload.role, {"student", "alumni", "admin", "staff"})
    user = db.query(models.User).filter(
        models.User.email == payload.email,
        models.User.role == role,
    ).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.password_hash = hash_password(payload.new_password)
    db.commit()
    return {"status": "password_updated"}


@app.post("/verify-otp", tags=["auth"])
def verify_otp(payload: VerifyOtpRequest, db: Session = Depends(get_db)):
    if not verify_stored_otp(payload.email, payload.otp):
        raise HTTPException(status_code=400, detail="Invalid OTP")

    role = ensure_role(payload.role, {"student", "alumni", "admin", "staff"})

    user = db.query(models.User).filter(models.User.email == payload.email).first()
    if not user:
        user = models.User(email=payload.email, full_name=payload.full_name, role=role)
        db.add(user)
        db.flush()

    user.full_name = payload.full_name
    user.role = role
    user.phone = payload.phone
    user.department = payload.department
    user.graduation_year = payload.graduation_year
    user.city = payload.city
    user.bio = payload.bio
    user.is_verified = True

    if role == "student":
        profile = db.query(models.StudentProfile).filter(models.StudentProfile.student_id == user.user_id).first()
        if not profile:
            profile = models.StudentProfile(student_id=user.user_id)
            db.add(profile)
        profile.skills = payload.skills
        profile.interests = payload.interests
        profile.resume_url = payload.resume_url

    if role == "alumni":
        profile = db.query(models.AlumniProfile).filter(models.AlumniProfile.alumni_id == user.user_id).first()
        if not profile:
            profile = models.AlumniProfile(alumni_id=user.user_id)
            db.add(profile)
        profile.company = payload.company
        profile.job_title = payload.job_title
        profile.mentorship_available = payload.mentorship_available
        profile.experience_summary = payload.bio

    db.commit()
    db.refresh(user)
    clear_otp(payload.email)

    access_token = create_access_token(data={"sub": str(user.user_id), "role": user.role})

    return {
        "status": "verified",
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user.user_id,
        "role": user.role,
    }


@app.get("/alumni", tags=["alumni"])
def list_alumni(
    department: Optional[str] = None,
    company: Optional[str] = None,
    city: Optional[str] = None,
    job_title: Optional[str] = None,
    db: Session = Depends(get_db),
):
    query = db.query(models.User, models.AlumniProfile).join(
        models.AlumniProfile, models.AlumniProfile.alumni_id == models.User.user_id
    )

    if department:
        query = query.filter(models.User.department.ilike(f"%{department}%"))
    if company:
        query = query.filter(models.AlumniProfile.company.ilike(f"%{company}%"))
    if city:
        query = query.filter(models.User.city.ilike(f"%{city}%"))
    if job_title:
        query = query.filter(models.AlumniProfile.job_title.ilike(f"%{job_title}%"))

    results = query.all()
    return [serialize_alumni(user, profile) for user, profile in results]


@app.get("/users", tags=["admin"])
def list_users(
    role: Optional[str] = None,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role not in {"admin", "staff"}:
        raise HTTPException(status_code=403, detail="Only admins or staff can list all users")
    
    query = db.query(models.User)
    if role:
        query = query.filter(models.User.role == role)
    
    users = query.all()
    return [serialize_user(u) for u in users]


@app.get("/admins", tags=["admin"])
def list_admin_contacts(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role not in {"admin", "alumni", "student"}:
        raise HTTPException(status_code=403, detail="Not authorized to view admin contacts")

    admins = (
        db.query(models.User)
        .filter(models.User.role == "admin")
        .order_by(models.User.full_name.asc())
        .all()
    )
    return [serialize_user(admin) for admin in admins]


@app.get("/profile/{user_id}", tags=["profile"])
def get_profile(user_id: int, db: Session = Depends(get_db)):
    user = get_user_by_id(db, user_id)
    data = serialize_user(user)

    if user.role == "student":
        profile = db.query(models.StudentProfile).filter(models.StudentProfile.student_id == user.user_id).first()
        data.update(
            {
                "skills": profile.skills if profile else None,
                "interests": profile.interests if profile else None,
                "resume_url": profile.resume_url if profile else None,
                "educational_details": profile.educational_details if profile else None,
            }
        )

    if user.role == "alumni":
        profile = db.query(models.AlumniProfile).filter(models.AlumniProfile.alumni_id == user.user_id).first()
        data.update(
            {
                "company": profile.company if profile else None,
                "job_title": profile.job_title if profile else None,
                "mentorship_available": profile.mentorship_available if profile else True,
                "experience_summary": profile.experience_summary if profile else None,
            }
        )

    return data


@app.get("/auth/me", tags=["auth"])
def read_users_me(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    return get_profile(current_user.user_id, db)


@app.patch("/profile/{user_id}", tags=["profile"])
def update_profile(user_id: int, payload: ProfileUpdateRequest, db: Session = Depends(get_db)):
    user = get_user_by_id(db, user_id)
    updates = payload.model_dump(exclude_unset=True) if hasattr(payload, "model_dump") else payload.dict(exclude_unset=True)

    for field, value in updates.items():
        if field in ["full_name", "phone", "department", "graduation_year", "city", "bio", "profile_picture_url", "current_status", "designation", "responsibilities"]:
            setattr(user, field, value)

    if user.role == "student":
        profile = db.query(models.StudentProfile).filter(models.StudentProfile.student_id == user.user_id).first()
        if not profile:
            profile = models.StudentProfile(student_id=user.user_id)
            db.add(profile)
        for field in ["skills", "interests", "resume_url", "educational_details"]:
            value = updates.get(field)
            if value is not None:
                setattr(profile, field, value)

    if user.role == "alumni":
        profile = db.query(models.AlumniProfile).filter(models.AlumniProfile.alumni_id == user.user_id).first()
        if not profile:
            profile = models.AlumniProfile(alumni_id=user.user_id)
            db.add(profile)
        if updates.get("company") is not None:
            profile.company = updates["company"]
        if updates.get("job_title") is not None:
            profile.job_title = updates["job_title"]
        if updates.get("mentorship_available") is not None:
            profile.mentorship_available = updates["mentorship_available"]
        if updates.get("experience_summary") is not None:
            profile.experience_summary = updates["experience_summary"]

    db.commit()
    return {"status": "updated"}


class EmailChangeRequest(BaseModel):
    user_id: int
    new_email: str


class EmailChangeVerifyRequest(BaseModel):
    user_id: int
    new_email: str
    otp: str


@app.post("/profile/request-email-change", tags=["profile"])
def request_email_change(payload: EmailChangeRequest, db: Session = Depends(get_db)):
    user = get_user_by_id(db, payload.user_id)

    # Check new email not already taken
    existing = db.query(models.User).filter(
        models.User.email == payload.new_email,
        models.User.user_id != payload.user_id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already in use by another account")

    send_otp_email_change(payload.new_email)
    return {"message": f"OTP sent to {payload.new_email}"}


@app.post("/profile/verify-email-change", tags=["profile"])
def verify_email_change(payload: EmailChangeVerifyRequest, db: Session = Depends(get_db)):
    if not verify_stored_otp(payload.new_email, payload.otp):
        raise HTTPException(status_code=400, detail="Invalid or expired OTP")

    user = get_user_by_id(db, payload.user_id)
    user.email = payload.new_email
    db.commit()
    clear_otp(payload.new_email)
    return {"status": "email_updated", "new_email": payload.new_email}


@app.delete("/profile/{user_id}")
def delete_profile(user_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.user_id != user_id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to delete this profile")
    
    user = get_user_by_id(db, user_id)
    try:
        # Remove dependent records first because most foreign keys do not use CASCADE.
        db.query(models.Connection).filter(
            (models.Connection.requester_id == user_id)
            | (models.Connection.receiver_id == user_id)
        ).delete(synchronize_session=False)

        db.query(models.Message).filter(
            (models.Message.sender_id == user_id)
            | (models.Message.receiver_id == user_id)
        ).delete(synchronize_session=False)

        db.query(models.Notification).filter(
            models.Notification.user_id == user_id
        ).delete(synchronize_session=False)

        db.query(models.Application).filter(
            models.Application.student_id == user_id
        ).delete(synchronize_session=False)

        internship_ids = [
            internship_id
            for (internship_id,) in db.query(models.Internship.internship_id)
            .filter(models.Internship.posted_by == user_id)
            .all()
        ]
        if internship_ids:
            db.query(models.Application).filter(
                models.Application.internship_id.in_(internship_ids)
            ).delete(synchronize_session=False)
            db.query(models.Internship).filter(
                models.Internship.internship_id.in_(internship_ids)
            ).delete(synchronize_session=False)

        db.query(models.Event).filter(
            models.Event.created_by == user_id
        ).delete(synchronize_session=False)

        db.query(models.Announcement).filter(
            models.Announcement.created_by == user_id
        ).delete(synchronize_session=False)

        db.query(models.StudentProfile).filter(
            models.StudentProfile.student_id == user_id
        ).delete(synchronize_session=False)
        db.query(models.AlumniProfile).filter(
            models.AlumniProfile.alumni_id == user_id
        ).delete(synchronize_session=False)

        db.delete(user)
        db.commit()
    except Exception:
        db.rollback()
        raise

    return {"status": "deleted"}


@app.post("/profile/{user_id}/resume", tags=["profile"])
def upload_resume(user_id: int, file: UploadFile = File(...), db: Session = Depends(get_db)):
    user = get_user_by_id(db, user_id)

    if user.role != "student":
        raise HTTPException(status_code=400, detail="Resume upload is only available for student users")

    filename = f"user_{user_id}_{file.filename}".replace(" ", "_")
    file_path = os.path.join(UPLOAD_DIR, filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    resume_url = f"/uploads/{filename}"
    profile = db.query(models.StudentProfile).filter(models.StudentProfile.student_id == user.user_id).first()
    if not profile:
        profile = models.StudentProfile(student_id=user.user_id)
        db.add(profile)
    profile.resume_url = resume_url
    db.commit()

    return {"status": "uploaded", "resume_url": resume_url}


@app.post("/upload", tags=["common"])
def upload_file(file: UploadFile = File(...)):
    filename = f"common_{file.filename}".replace(" ", "_")
    file_path = os.path.join(UPLOAD_DIR, filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    file_url = f"/uploads/{filename}"
    return {"status": "uploaded", "url": file_url}


@app.post("/internships", tags=["internships"])
def create_internship(payload: InternshipCreate, db: Session = Depends(get_db)):
    user = get_user_by_id(db, payload.posted_by)
    if user.role != "alumni":
        raise HTTPException(status_code=400, detail="Only alumni users can post internships")

    internship = models.Internship(**payload_dict(payload))
    db.add(internship)
    db.commit()
    db.refresh(internship)
    return {"internship_id": internship.internship_id, "message": "Internship created"}


@app.get("/internships", tags=["internships"])
def list_internships(
    role_title: Optional[str] = None,
    location: Optional[str] = None,
    stipend: Optional[str] = None,
    db: Session = Depends(get_db),
):
    query = db.query(models.Internship)
    if role_title:
        query = query.filter(models.Internship.role_title.ilike(f"%{role_title}%"))
    if location:
        query = query.filter(models.Internship.location.ilike(f"%{location}%"))
    if stipend:
        query = query.filter(models.Internship.stipend.ilike(f"%{stipend}%"))
    internships = query.order_by(models.Internship.created_at.desc()).all()

    result = []
    for i in internships:
        poster = db.query(models.User).filter(models.User.user_id == i.posted_by).first()
        result.append({
            "internship_id": i.internship_id,
            "posted_by": i.posted_by,
            "posted_by_name": poster.full_name if poster else "Unknown",
            "company_name": i.company,
            "role_title": i.role_title,
            "description": i.description,
            "location": i.location,
            "duration": i.duration,
            "stipend": i.stipend,
            "skills_required": i.required_skills,
            "apply_deadline": i.deadline,
            "seats_available": i.seats,
            "status": i.status,
            "created_at": i.created_at.isoformat(),
        })
    return result


@app.post("/applications", tags=["applications"])
def apply_for_internship(payload: ApplicationCreate, db: Session = Depends(get_db)):
    student = get_user_by_id(db, payload.student_id)
    internship = get_internship_by_id(db, payload.internship_id)

    if student.role != "student":
        raise HTTPException(status_code=400, detail="Only students can apply for internships")

    existing = db.query(models.Application).filter(
        models.Application.internship_id == payload.internship_id,
        models.Application.student_id == payload.student_id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Student already applied for this internship")

    application = models.Application(**payload_dict(payload))
    db.add(application)
    db.flush()

    # Notify the alumni who posted this internship
    notification = models.Notification(
        user_id=internship.posted_by,
        message=f"{student.full_name} applied for your '{internship.role_title}' internship at {internship.company}.",
        is_read=False,
    )
    db.add(notification)
    db.commit()
    db.refresh(application)
    return {"application_id": application.application_id, "status": application.status}


@app.get("/internships/{internship_id}/applicants", tags=["applications"])
def get_internship_applicants(
    internship_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    internship = get_internship_by_id(db, internship_id)
    if current_user.role not in {"alumni", "admin"}:
        raise HTTPException(status_code=403, detail="Only alumni or admin can view applicants")
    if current_user.role == "alumni" and internship.posted_by != current_user.user_id:
        raise HTTPException(status_code=403, detail="You can only view applicants for your own internships")

    applications = db.query(models.Application).filter(
        models.Application.internship_id == internship_id
    ).order_by(models.Application.applied_at.desc()).all()

    result = []
    for app in applications:
        student = db.query(models.User).filter(models.User.user_id == app.student_id).first()
        student_profile = db.query(models.StudentProfile).filter(
            models.StudentProfile.student_id == app.student_id
        ).first()
        result.append({
            "application_id": app.application_id,
            "status": app.status,
            "cover_note": app.cover_note,
            "applied_at": app.applied_at.isoformat(),
            "student": {
                "user_id": student.user_id,
                "full_name": student.full_name,
                "email": student.email,
                "phone": student.phone,
                "department": student.department,
                "graduation_year": student.graduation_year,
                "city": student.city,
                "skills": student_profile.skills if student_profile else None,
                "resume_url": student_profile.resume_url if student_profile else None,
            } if student else None,
        })
    return result


@app.patch("/applications/{application_id}", tags=["applications"])
def update_application_status(
    application_id: int,
    payload: ApplicationStatusUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "alumni":
        raise HTTPException(status_code=403, detail="Only alumni can update application status")

    allowed_statuses = {"Applied", "Shortlisted", "Rejected", "Selected"}
    if payload.status not in allowed_statuses:
        raise HTTPException(status_code=400, detail="Invalid application status")

    application = get_application_by_id(db, application_id)

    # Ensure the alumni owns the internship this application belongs to
    internship = get_internship_by_id(db, application.internship_id)
    if internship.posted_by != current_user.user_id:
        raise HTTPException(status_code=403, detail="You can only update status for your own internship applicants")

    application.status = payload.status
    db.commit()
    return {"application_id": application.application_id, "status": application.status}


@app.patch("/internships/{internship_id}", tags=["internships"])
def update_internship(internship_id: int, payload: InternshipCreate, db: Session = Depends(get_db)):
    internship = get_internship_by_id(db, internship_id)
    updates = payload_dict(payload)
    for field, value in updates.items():
        if value is not None:
            setattr(internship, field, value)
    db.commit()
    return {"status": "updated"}


@app.delete("/internships/{internship_id}", tags=["internships"])
def delete_internship(internship_id: int, db: Session = Depends(get_db)):
    internship = get_internship_by_id(db, internship_id)
    # Delete related applications first to avoid foreign key constraint errors
    db.query(models.Application).filter(
        models.Application.internship_id == internship_id
    ).delete(synchronize_session=False)
    db.delete(internship)
    db.commit()
    return {"status": "deleted"}


@app.delete("/applications/{application_id}", tags=["applications"])
def delete_application(application_id: int, db: Session = Depends(get_db)):
    application = get_application_by_id(db, application_id)
    db.delete(application)
    db.commit()
    return {"status": "deleted"}


@app.get("/applications", tags=["applications"])
def list_applications(
    internship_id: Optional[int] = None,
    student_id: Optional[int] = None,
    db: Session = Depends(get_db),
):
    query = db.query(models.Application)
    if internship_id:
        query = query.filter(models.Application.internship_id == internship_id)
    if student_id:
        query = query.filter(models.Application.student_id == student_id)
    return query.order_by(models.Application.applied_at.desc()).all()


@app.post("/events", tags=["events"])
def create_event(payload: EventCreate, db: Session = Depends(get_db)):
    user = get_user_by_id(db, payload.created_by)
    if user.role not in {"admin", "staff"}:
        raise HTTPException(status_code=400, detail="Only admin or staff can create events")

    event = models.Event(**payload_dict(payload))
    db.add(event)
    db.commit()
    db.refresh(event)

    # Auto-notify target audience
    _notify_audience(
        db=db,
        target_role=payload.target_audience,
        sender_id=user.user_id,
        noti_type="event",
        message=f"📅 New Event: {payload.title}" + (f" on {payload.date}" if payload.date else ""),
    )

    return {"event_id": event.event_id, "message": "Event created"}


@app.get("/events", tags=["events"])
def list_events(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role in {"admin", "staff"}:
        return db.query(models.Event).order_by(models.Event.created_at.desc()).all()
    
    return db.query(models.Event).filter(
        (models.Event.target_audience == "all") | (models.Event.target_audience == current_user.role)
    ).order_by(models.Event.created_at.desc()).all()


@app.patch("/events/{event_id}", tags=["events"])
def update_event(event_id: int, payload: EventCreate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only admins can update events")
    
    event = db.query(models.Event).filter(models.Event.event_id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    event.title = payload.title
    event.date = payload.date
    event.location = payload.location
    event.description = payload.description
    event.category = payload.category
    event.target_audience = payload.target_audience
    db.commit()
    return {"status": "updated", "event_id": event.event_id}


@app.delete("/events/{event_id}", tags=["events"])
def delete_event(event_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only admins can delete events")

    event = db.query(models.Event).filter(models.Event.event_id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    db.delete(event)
    db.commit()
    return {"status": "deleted"}


@app.delete("/events", tags=["events"])
def delete_all_events(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role not in {"admin", "staff"}:
        raise HTTPException(status_code=403, detail="Only admins or staff can delete all events")

    db.query(models.Event).delete()
    db.commit()
    return {"status": "all deleted"}


@app.post("/connections", tags=["connections"])
def create_connection(
    payload: ConnectionCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    requester = get_user_by_id(db, payload.requester_id)
    receiver = get_user_by_id(db, payload.receiver_id)

    if current_user.user_id != payload.requester_id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to send this connection request")
    if requester.user_id == receiver.user_id:
        raise HTTPException(status_code=400, detail="Users cannot connect to themselves")
    if requester.role != "student":
        raise HTTPException(status_code=400, detail="Only students can initiate connection requests")
    if receiver.role != "alumni":
        raise HTTPException(status_code=400, detail="Students can only connect with alumni")

    existing = db.query(models.Connection).filter(
        (
            (models.Connection.requester_id == payload.requester_id)
            & (models.Connection.receiver_id == payload.receiver_id)
        )
        | (
            (models.Connection.requester_id == payload.receiver_id)
            & (models.Connection.receiver_id == payload.requester_id)
        )
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Connection already exists between these users")

    connection = models.Connection(**payload_dict(payload))
    db.add(connection)
    db.commit()
    db.refresh(connection)
    return {"connection_id": connection.connection_id, "status": connection.status}


@app.patch("/connections/{connection_id}", tags=["connections"])
def update_connection_status(
    connection_id: int,
    payload: ConnectionStatusUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    allowed_statuses = {"accepted", "rejected"}
    normalized_status = payload.status.lower()
    if normalized_status not in allowed_statuses:
        raise HTTPException(status_code=400, detail="Invalid connection status")

    connection = get_connection_by_id(db, connection_id)
    if current_user.user_id != connection.receiver_id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Only the receiving alumni can respond to this request")
    if connection.status != "pending":
        raise HTTPException(status_code=400, detail="Only pending requests can be updated")

    connection.status = normalized_status
    db.commit()
    return {"connection_id": connection.connection_id, "status": connection.status}


@app.delete("/connections/{connection_id}", tags=["connections"])
def delete_connection(
    connection_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    connection = get_connection_by_id(db, connection_id)
    if current_user.user_id not in {connection.requester_id, connection.receiver_id} and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to delete this connection")
    db.delete(connection)
    db.commit()
    return {"status": "deleted"}


@app.post("/announcements")
def create_announcement(payload: AnnouncementCreate, db: Session = Depends(get_db)):
    user = get_user_by_id(db, payload.created_by)
    if user.role != "admin":
        raise HTTPException(status_code=400, detail="Only admin users can post announcements")
    announcement = models.Announcement(**payload_dict(payload))
    db.add(announcement)
    db.commit()
    db.refresh(announcement)
    return {"announcement_id": announcement.announcement_id, "message": "Announcement created"}


@app.get("/announcements")
def list_announcements(db: Session = Depends(get_db)):
    return db.query(models.Announcement).order_by(models.Announcement.created_at.desc()).all()


@app.patch("/announcements/{announcement_id}")
def update_announcement(announcement_id: int, payload: AnnouncementCreate, db: Session = Depends(get_db)):
    announcement = get_announcement_by_id(db, announcement_id)
    updates = payload_dict(payload)
    for field, value in updates.items():
        if value is not None:
            setattr(announcement, field, value)
    db.commit()
    return {"status": "updated"}


@app.delete("/announcements/{announcement_id}")
def delete_announcement(announcement_id: int, db: Session = Depends(get_db)):
    announcement = get_announcement_by_id(db, announcement_id)
    db.delete(announcement)
    db.commit()
    return {"status": "deleted"}


@app.get("/connections", tags=["connections"])
def list_connections(
    user_id: int,
    role: Optional[str] = None,
    status: Optional[str] = None,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    get_user_by_id(db, user_id)
    if current_user.user_id != user_id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to view these connections")

    if role == "alumni":
        query = (
            db.query(models.Connection, models.User)
            .join(models.User, models.User.user_id == models.Connection.requester_id)
            .filter(models.Connection.receiver_id == user_id)
        )
        if status:
            query = query.filter(models.Connection.status == status.lower())
        else:
            query = query.filter(models.Connection.status == "pending")

        results = query.order_by(models.Connection.created_at.desc()).all()
        return [
            {
                "connection_id": conn.connection_id,
                "status": conn.status,
                "created_at": conn.created_at.isoformat(),
                "requester": {
                    "user_id": requester.user_id,
                    "full_name": requester.full_name,
                    "email": requester.email,
                    "role": requester.role,
                    "department": requester.department,
                    "graduation_year": requester.graduation_year,
                    "city": requester.city,
                    "profile_picture_url": requester.profile_picture_url,
                },
            }
            for conn, requester in results
        ]

    query = (
        db.query(models.Connection, models.User)
        .join(models.User, models.User.user_id == models.Connection.receiver_id)
        .filter(models.Connection.requester_id == user_id)
    )
    if status:
        query = query.filter(models.Connection.status == status.lower())

    results = query.order_by(models.Connection.created_at.desc()).all()
    return [
        {
            "connection_id": conn.connection_id,
            "status": conn.status,
            "created_at": conn.created_at.isoformat(),
            "receiver": {
                "user_id": receiver.user_id,
                "full_name": receiver.full_name,
                "email": receiver.email,
                "role": receiver.role,
                "department": receiver.department,
                "graduation_year": receiver.graduation_year,
                "city": receiver.city,
                "profile_picture_url": receiver.profile_picture_url,
            },
        }
        for conn, receiver in results
    ]


@app.post("/messages", tags=["messages"])
def create_message(payload: MessageCreate, db: Session = Depends(get_db)):
    sender = get_user_by_id(db, payload.sender_id)
    receiver = get_user_by_id(db, payload.receiver_id)
    ensure_connected(db, sender.user_id, receiver.user_id)

    message = models.Message(**payload_dict(payload))
    db.add(message)
    db.commit()
    db.refresh(message)
    return {"message_id": message.message_id, "sent_at": message.sent_at}


@app.get("/conversations", tags=["messages"])
def list_conversations(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Get all messages where user is either sender or receiver
    sender_ids = [m.receiver_id for m in db.query(models.Message).filter(models.Message.sender_id == current_user.user_id).all()]
    receiver_ids = [m.sender_id for m in db.query(models.Message).filter(models.Message.receiver_id == current_user.user_id).all()]
    
    unique_ids = list(set(sender_ids + receiver_ids))
    other_users = db.query(models.User).filter(models.User.user_id.in_(unique_ids)).all()
    
    return [serialize_user(u) for u in other_users]


@app.patch("/messages/{message_id}", tags=["messages"])
def edit_message(message_id: int, content: str = Body(..., embed=True), current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    message = db.query(models.Message).filter(models.Message.message_id == message_id).first()
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    
    if message.sender_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="Not authorized to edit this message")

    now = datetime.now(timezone.utc)
    sent_at = message.sent_at.replace(tzinfo=timezone.utc) if message.sent_at.tzinfo is None else message.sent_at
    
    if now - sent_at > timedelta(minutes=5):
        raise HTTPException(status_code=400, detail="Edit period (5 mins) has expired")

    message.content = content
    db.commit()
    return {"status": "updated", "content": content}


@app.delete("/messages/clear", tags=["messages"])
def clear_chat(other_user_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Deletes all messages between current_user and another user
    messages = db.query(models.Message).filter(
        (
            (models.Message.sender_id == current_user.user_id)
            & (models.Message.receiver_id == other_user_id)
        )
        | (
            (models.Message.sender_id == other_user_id)
            & (models.Message.receiver_id == current_user.user_id)
        )
    ).all()
    
    count = 0
    for msg in messages:
        db.delete(msg)
        count += 1
        
    db.commit()
    return {"status": "cleared", "count": count}


@app.delete("/messages/{message_id}", tags=["messages"])
def delete_message(message_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    message = db.query(models.Message).filter(models.Message.message_id == message_id).first()
    if not message:
        raise HTTPException(status_code=404, detail="Message not found")
    
    if message.sender_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this message")

    now = datetime.now(timezone.utc)
    sent_at = message.sent_at.replace(tzinfo=timezone.utc) if message.sent_at.tzinfo is None else message.sent_at
    
    if now - sent_at > timedelta(hours=24):
        raise HTTPException(status_code=400, detail="Deletion period (24 hours) has expired")

    db.delete(message)
    db.commit()
    return {"status": "deleted"}


@app.post("/messages/bulk-delete", tags=["messages"])
def bulk_delete_messages(message_ids: list[int], current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    
    # Query only messages that belong to user and are < 24h old
    messages = db.query(models.Message).filter(
        models.Message.message_id.in_(message_ids),
        models.Message.sender_id == current_user.user_id
    ).all()
    
    deleted_count = 0
    for msg in messages:
        sent_at = msg.sent_at.replace(tzinfo=timezone.utc) if msg.sent_at.tzinfo is None else msg.sent_at
        if now - sent_at <= timedelta(hours=24):
            db.delete(msg)
            deleted_count += 1
            
    db.commit()
    return {"status": "deleted", "count": deleted_count}



@app.get("/messages", tags=["messages"])
def list_messages(user_id: int, other_user_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    get_user_by_id(db, user_id)
    get_user_by_id(db, other_user_id)
    
    if current_user.user_id != user_id and current_user.user_id != other_user_id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to see these messages")

    ensure_connected(db, user_id, other_user_id)

    messages = db.query(models.Message).filter(
        (
            (models.Message.sender_id == user_id)
            & (models.Message.receiver_id == other_user_id)
        )
        | (
            (models.Message.sender_id == other_user_id)
            & (models.Message.receiver_id == user_id)
        )
    ).order_by(models.Message.sent_at.asc()).all()

    # Mark messages sent to current user as read
    db.query(models.Message).filter(
        models.Message.sender_id == other_user_id,
        models.Message.receiver_id == current_user.user_id,
        models.Message.is_read == False,
    ).update({"is_read": True})
    db.commit()

    return [
        {
            "message_id": m.message_id,
            "sender_id": m.sender_id,
            "receiver_id": m.receiver_id,
            "content": m.content,
            "sent_at": m.sent_at.isoformat(),
            "is_read": m.is_read,
        }
        for m in messages
    ]


@app.get("/messages/unread-count", tags=["messages"])
def get_unread_count(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    count = db.query(models.Message).filter(
        models.Message.receiver_id == current_user.user_id,
        models.Message.is_read == False,
    ).count()
    return {"unread_count": count}


@app.post("/resources", tags=["resources"])
def create_resource(payload: ResourceCreate, db: Session = Depends(get_db)):
    user = get_user_by_id(db, payload.created_by)
    if user.role not in {"staff", "admin"}:
        raise HTTPException(status_code=400, detail="Only staff or admin users can create resources")

    resource = models.Resource(**payload_dict(payload))
    db.add(resource)
    db.commit()
    db.refresh(resource)

    # Auto-notify target audience
    type_label = "📄 Document" if payload.resource_type == "document" else "🔗 Link"
    _notify_audience(
        db=db,
        target_role=payload.target_audience,
        sender_id=user.user_id,
        noti_type="broadcast",
        message=f"{type_label} shared: {payload.title}",
    )

    return {"resource_id": resource.resource_id, "message": "Resource created"}


@app.get("/resources", tags=["resources"])
def list_resources(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role in {"admin", "staff"}:
        return db.query(models.Resource).order_by(models.Resource.created_at.desc()).all()
    
    return db.query(models.Resource).filter(
        (models.Resource.target_audience == "all") | (models.Resource.target_audience == current_user.role)
    ).order_by(models.Resource.created_at.desc()).all()


@app.delete("/resources/{resource_id}", tags=["resources"])
def delete_resource(resource_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    resource = db.query(models.Resource).filter(models.Resource.resource_id == resource_id).first()
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    
    if current_user.role not in {"admin", "staff"} and resource.created_by != current_user.user_id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this resource")

    db.delete(resource)
    db.commit()
    return {"status": "deleted"}


@app.post("/notifications")
def create_notification(payload: NotificationCreate, db: Session = Depends(get_db)):
    get_user_by_id(db, payload.user_id)
    notification = models.Notification(**payload_dict(payload))
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return {"noti_id": notification.noti_id, "message": "Notification created"}


@app.get("/notifications/unread-count", tags=["events"])
def get_unread_notification_count(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    count = db.query(models.Notification).filter(
        models.Notification.user_id == current_user.user_id,
        models.Notification.is_read == False,
    ).count()
    return {"unread_count": count}


@app.get("/notifications", tags=["events"])
def list_notifications(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(models.Notification).filter(
        models.Notification.user_id == current_user.user_id
    ).order_by(models.Notification.created_at.desc()).all()


@app.patch("/notifications/mark-all-read", tags=["events"])
def mark_all_notifications_read(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.query(models.Notification).filter(
        models.Notification.user_id == current_user.user_id,
        models.Notification.is_read == False,
    ).update({"is_read": True})
    db.commit()
    return {"status": "all_marked_read"}


@app.delete("/notifications/clear-all", tags=["events"])
def clear_all_notifications(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.query(models.Notification).filter(
        models.Notification.user_id == current_user.user_id,
    ).delete(synchronize_session=False)
    db.commit()
    return {"status": "cleared"}


class BroadcastNotificationRequest(BaseModel):
    title: str
    message: str
    target_role: str  # "all", "student", "alumni", "staff"


@app.post("/notifications/broadcast", tags=["events"])
def broadcast_notification(
    payload: BroadcastNotificationRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role not in {"admin", "staff"}:
        raise HTTPException(status_code=403, detail="Only admin or staff can broadcast notifications")

    query = db.query(models.User)
    if payload.target_role != "all":
        query = query.filter(models.User.role == payload.target_role)

    users = query.all()
    full_message = f"{payload.title}: {payload.message}" if payload.title else payload.message

    count = 0
    for user in users:
        if user.user_id == current_user.user_id:
            continue
        db.add(models.Notification(
            user_id=user.user_id,
            type="broadcast",
            message=full_message,
            is_read=False,
        ))
        count += 1

    db.add(models.BroadcastLog(
        sent_by=current_user.user_id,
        title=payload.title,
        message=payload.message,
        target_role=payload.target_role,
        recipient_count=count,
    ))
    db.commit()
    return {"status": "sent", "recipients": count}


@app.get("/notifications/sent", tags=["events"])
def get_sent_notifications(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role not in {"admin", "staff"}:
        raise HTTPException(status_code=403, detail="Not authorized")

    logs = db.query(models.BroadcastLog).filter(
        models.BroadcastLog.sent_by == current_user.user_id
    ).order_by(models.BroadcastLog.created_at.desc()).all()

    return [
        {
            "log_id": log.log_id,
            "title": log.title,
            "message": log.message,
            "target_role": log.target_role,
            "recipient_count": log.recipient_count,
            "created_at": log.created_at.isoformat() if log.created_at else None,
        }
        for log in logs
    ]


class BroadcastLogDeleteRequest(BaseModel):
    log_ids: list[int]


@app.post("/notifications/sent/delete", tags=["events"])
def delete_broadcast_logs(
    payload: BroadcastLogDeleteRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role not in {"admin", "staff"}:
        raise HTTPException(status_code=403, detail="Not authorized")

    db.query(models.BroadcastLog).filter(
        models.BroadcastLog.log_id.in_(payload.log_ids),
        models.BroadcastLog.sent_by == current_user.user_id,
    ).delete(synchronize_session=False)
    db.commit()
    return {"status": "deleted", "count": len(payload.log_ids)}


# Parameterized routes LAST — must come after all specific /notifications/* paths
@app.patch("/notifications/{noti_id}/read")
def mark_notification_as_read(noti_id: int, db: Session = Depends(get_db)):
    notification = get_notification_by_id(db, noti_id)
    notification.is_read = True
    db.commit()
    return {"status": "marked_as_read"}


@app.delete("/notifications/{noti_id}")
def delete_notification(noti_id: int, db: Session = Depends(get_db)):
    notification = get_notification_by_id(db, noti_id)
    db.delete(notification)
    db.commit()
    return {"status": "deleted"}

@app.on_event("startup")
def startup():
    init_db()