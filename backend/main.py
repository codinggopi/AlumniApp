import os
import shutil
from typing import Optional

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile, status
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy.orm import Session

try:
    from .auth import ALGORITHM, SECRET_KEY, clear_otp, create_access_token, hash_password, send_otp_email, verify_password, verify_stored_otp
    from .database import get_session, init_db
    from . import models
except ImportError:
    from auth import ALGORITHM, SECRET_KEY, clear_otp, create_access_token, hash_password, send_otp_email, verify_password, verify_stored_otp
    from database import get_session, init_db
    import models
from jose import JWTError, jwt


init_db()

app = FastAPI(title="Alumni App API")
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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


class AnnouncementCreate(BaseModel):
    created_by: int
    title: str
    content: str


class ConnectionCreate(BaseModel):
    requester_id: int
    receiver_id: int


class ConnectionStatusUpdate(BaseModel):
    status: str


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


def serialize_user(user: models.User):
    return {
        "user_id": user.user_id,
        "email": user.email,
        "full_name": user.full_name,
        "role": user.role,
        "phone": user.phone,
        "department": user.department,
        "graduation_year": user.graduation_year,
        "city": user.city,
        "bio": user.bio,
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


def ensure_connected(db: Session, sender_id: int, receiver_id: int):
    connection = db.query(models.Connection).filter(
        (
            (models.Connection.requester_id == sender_id)
            & (models.Connection.receiver_id == receiver_id)
        )
        | (
            (models.Connection.requester_id == receiver_id)
            & (models.Connection.receiver_id == sender_id)
        ),
        models.Connection.status == "accepted",
    ).first()
    if not connection:
        raise HTTPException(status_code=400, detail="Users must be connected before messaging")
    return connection


@app.get("/")
def home():
    return {
        "message": "Alumni App backend running",
        "modules": ["auth", "directory", "internships", "applications", "events"],
    }


@app.post("/send-otp")
def send_otp(payload: SendOtpRequest):
    send_otp_email(payload.email)
    return {"message": "OTP sent", "expires_in_minutes": 5}


@app.post("/auth/register")
def register_with_password(payload: AuthRegisterRequest, db: Session = Depends(get_db)):
    role = ensure_role(payload.role, {"student", "alumni", "admin"})

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


@app.post("/auth/login")
def login_with_password(payload: AuthLoginRequest, db: Session = Depends(get_db)):
    role = ensure_role(payload.role, {"student", "alumni", "admin"})
    user = db.query(models.User).filter(
        models.User.email == payload.email,
        models.User.role == role,
    ).first()

    if not user or not verify_password(payload.password, user.password_hash):
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


@app.post("/auth/reset-password")
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)):
    role = ensure_role(payload.role, {"student", "alumni", "admin"})
    user = db.query(models.User).filter(
        models.User.email == payload.email,
        models.User.role == role,
    ).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.password_hash = hash_password(payload.new_password)
    db.commit()
    return {"status": "password_updated"}


@app.post("/verify-otp")
def verify_otp(payload: VerifyOtpRequest, db: Session = Depends(get_db)):
    if not verify_stored_otp(payload.email, payload.otp):
        raise HTTPException(status_code=400, detail="Invalid OTP")

    role = ensure_role(payload.role, {"student", "alumni", "admin"})

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


@app.get("/alumni")
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


@app.get("/profile/{user_id}")
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


@app.get("/auth/me")
def read_users_me(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    return get_profile(current_user.user_id, db)


@app.patch("/profile/{user_id}")
def update_profile(user_id: int, payload: ProfileUpdateRequest, db: Session = Depends(get_db)):
    user = get_user_by_id(db, user_id)
    updates = payload_dict(payload)

    for field in ["full_name", "phone", "department", "graduation_year", "city", "bio"]:
        value = updates.get(field)
        if value is not None:
            setattr(user, field, value)

    if user.role == "student":
        profile = db.query(models.StudentProfile).filter(models.StudentProfile.student_id == user.user_id).first()
        if not profile:
            profile = models.StudentProfile(student_id=user.user_id)
            db.add(profile)
        for field in ["skills", "interests", "resume_url"]:
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


@app.delete("/profile/{user_id}")
def delete_profile(user_id: int, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.user_id != user_id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Not authorized to delete this profile")
    
    user = get_user_by_id(db, user_id)
    # Delete profiles first due to FK constraints if not using CASCADE
    db.query(models.StudentProfile).filter(models.StudentProfile.student_id == user_id).delete()
    db.query(models.AlumniProfile).filter(models.AlumniProfile.alumni_id == user_id).delete()
    db.delete(user)
    db.commit()
    return {"status": "deleted"}


@app.post("/profile/{user_id}/resume")
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


@app.post("/internships")
def create_internship(payload: InternshipCreate, db: Session = Depends(get_db)):
    user = get_user_by_id(db, payload.posted_by)
    if user.role != "alumni":
        raise HTTPException(status_code=400, detail="Only alumni users can post internships")

    internship = models.Internship(**payload_dict(payload))
    db.add(internship)
    db.commit()
    db.refresh(internship)
    return {"internship_id": internship.internship_id, "message": "Internship created"}


@app.get("/internships")
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
    return query.order_by(models.Internship.created_at.desc()).all()


@app.post("/applications")
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
    db.commit()
    db.refresh(application)
    return {"application_id": application.application_id, "status": application.status}


@app.patch("/applications/{application_id}")
def update_application_status(application_id: int, payload: ApplicationStatusUpdate, db: Session = Depends(get_db)):
    allowed_statuses = {"Applied", "Shortlisted", "Rejected", "Selected"}
    if payload.status not in allowed_statuses:
        raise HTTPException(status_code=400, detail="Invalid application status")

    application = get_application_by_id(db, application_id)

    application.status = payload.status
    db.commit()
    return {"application_id": application.application_id, "status": application.status}


@app.patch("/internships/{internship_id}")
def update_internship(internship_id: int, payload: InternshipCreate, db: Session = Depends(get_db)):
    internship = get_internship_by_id(db, internship_id)
    updates = payload_dict(payload)
    for field, value in updates.items():
        if value is not None:
            setattr(internship, field, value)
    db.commit()
    return {"status": "updated"}


@app.delete("/internships/{internship_id}")
def delete_internship(internship_id: int, db: Session = Depends(get_db)):
    internship = get_internship_by_id(db, internship_id)
    db.delete(internship)
    db.commit()
    return {"status": "deleted"}


@app.delete("/applications/{application_id}")
def delete_application(application_id: int, db: Session = Depends(get_db)):
    application = get_application_by_id(db, application_id)
    db.delete(application)
    db.commit()
    return {"status": "deleted"}


@app.get("/applications")
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


@app.post("/events")
def create_event(payload: EventCreate, db: Session = Depends(get_db)):
    user = get_user_by_id(db, payload.created_by)
    if user.role != "admin":
        raise HTTPException(status_code=400, detail="Only admin users can create events")

    event = models.Event(**payload_dict(payload))
    db.add(event)
    db.commit()
    db.refresh(event)
    return {"event_id": event.event_id, "message": "Event created"}


@app.get("/events")
def list_events(db: Session = Depends(get_db)):
    return db.query(models.Event).order_by(models.Event.created_at.desc()).all()


@app.patch("/events/{event_id}")
def update_event(event_id: int, payload: EventCreate, db: Session = Depends(get_db)):
    event = db.query(models.Event).filter(models.Event.event_id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    admin_user = get_user_by_id(db, payload.created_by)
    if admin_user.role != "admin":
        raise HTTPException(status_code=400, detail="Only admin users can update events")

    event.title = payload.title
    event.date = payload.date
    event.location = payload.location
    event.description = payload.description
    event.category = payload.category
    db.commit()
    return {"status": "updated", "event_id": event.event_id}


@app.delete("/events/{event_id}")
def delete_event(event_id: int, created_by: int, db: Session = Depends(get_db)):
    event = db.query(models.Event).filter(models.Event.event_id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    admin_user = get_user_by_id(db, created_by)
    if admin_user.role != "admin":
        raise HTTPException(status_code=400, detail="Only admin users can delete events")

    db.delete(event)
    db.commit()
    return {"status": "deleted"}


@app.post("/connections")
def create_connection(payload: ConnectionCreate, db: Session = Depends(get_db)):
    requester = get_user_by_id(db, payload.requester_id)
    receiver = get_user_by_id(db, payload.receiver_id)

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


@app.patch("/connections/{connection_id}")
def update_connection_status(connection_id: int, payload: ConnectionStatusUpdate, db: Session = Depends(get_db)):
    allowed_statuses = {"pending", "accepted", "declined"}
    normalized_status = payload.status.lower()
    if normalized_status not in allowed_statuses:
        raise HTTPException(status_code=400, detail="Invalid connection status")

    connection = get_connection_by_id(db, connection_id)
    connection.status = normalized_status
    db.commit()
    return {"connection_id": connection.connection_id, "status": connection.status}


@app.delete("/connections/{connection_id}")
def delete_connection(connection_id: int, db: Session = Depends(get_db)):
    connection = get_connection_by_id(db, connection_id)
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


@app.get("/connections")
def list_connections(user_id: int, status: Optional[str] = None, db: Session = Depends(get_db)):
    get_user_by_id(db, user_id)

    query = db.query(models.Connection).filter(
        (models.Connection.requester_id == user_id) | (models.Connection.receiver_id == user_id)
    )
    if status:
        query = query.filter(models.Connection.status == status.lower())
    return query.order_by(models.Connection.created_at.desc()).all()


@app.post("/messages")
def create_message(payload: MessageCreate, db: Session = Depends(get_db)):
    sender = get_user_by_id(db, payload.sender_id)
    receiver = get_user_by_id(db, payload.receiver_id)
    ensure_connected(db, sender.user_id, receiver.user_id)

    message = models.Message(**payload_dict(payload))
    db.add(message)
    db.commit()
    db.refresh(message)
    return {"message_id": message.message_id, "sent_at": message.sent_at}


@app.get("/messages")
def list_messages(user_id: int, other_user_id: int, db: Session = Depends(get_db)):
    get_user_by_id(db, user_id)
    get_user_by_id(db, other_user_id)
    ensure_connected(db, user_id, other_user_id)

    return db.query(models.Message).filter(
        (
            (models.Message.sender_id == user_id)
            & (models.Message.receiver_id == other_user_id)
        )
        | (
            (models.Message.sender_id == other_user_id)
            & (models.Message.receiver_id == user_id)
        )
    ).order_by(models.Message.sent_at.asc()).all()


@app.post("/notifications")
def create_notification(payload: NotificationCreate, db: Session = Depends(get_db)):
    get_user_by_id(db, payload.user_id)
    notification = models.Notification(**payload_dict(payload))
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return {"noti_id": notification.noti_id, "message": "Notification created"}


@app.get("/notifications")
def list_notifications(user_id: int, db: Session = Depends(get_db)):
    get_user_by_id(db, user_id)
    return db.query(models.Notification).filter(models.Notification.user_id == user_id).order_by(models.Notification.created_at.desc()).all()


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
