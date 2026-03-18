from typing import Optional

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session

try:
    from .auth import clear_otp, send_otp_email, verify_stored_otp
    from .database import get_session, init_db
    from . import models
except ImportError:
    from auth import clear_otp, send_otp_email, verify_stored_otp
    from database import get_session, init_db
    import models


init_db()

app = FastAPI(title="Alumni App API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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


class ConnectionCreate(BaseModel):
    requester_id: int
    receiver_id: int


class ConnectionStatusUpdate(BaseModel):
    status: str


class MessageCreate(BaseModel):
    sender_id: int
    receiver_id: int
    content: str


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


def get_connection_by_id(db: Session, connection_id: int):
    connection = db.query(models.Connection).filter(models.Connection.connection_id == connection_id).first()
    if not connection:
        raise HTTPException(status_code=404, detail="Connection not found")
    return connection


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

    return {"status": "verified", "user_id": user.user_id, "role": user.role}


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
