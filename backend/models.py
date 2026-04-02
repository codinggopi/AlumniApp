from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

try:
    from .database import Base
except ImportError:
    from database import Base


class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    full_name = Column(String(120), nullable=False)
    role = Column(String(50), nullable=False, index=True)
    password_hash = Column(String(255), nullable=True)
    phone = Column(String(20), nullable=True)
    department = Column(String(120), nullable=True)
    graduation_year = Column(Integer, nullable=True)
    city = Column(String(120), nullable=True)
    bio = Column(Text, nullable=True)
    profile_picture_url = Column(String(255), nullable=True)
    current_status = Column(String(200), nullable=True)
    designation = Column(String(120), nullable=True)
    responsibilities = Column(Text, nullable=True)
    is_verified = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    student_profile = relationship("StudentProfile", back_populates="user", uselist=False)
    alumni_profile = relationship("AlumniProfile", back_populates="user", uselist=False)
    sent_connections = relationship("Connection", foreign_keys="Connection.requester_id", overlaps="requester")
    received_connections = relationship("Connection", foreign_keys="Connection.receiver_id", overlaps="receiver")
    sent_messages = relationship("Message", foreign_keys="Message.sender_id", overlaps="sender")
    received_messages = relationship("Message", foreign_keys="Message.receiver_id", overlaps="receiver")
    internships = relationship("Internship", foreign_keys="Internship.posted_by", overlaps="alumni")
    applications = relationship("Application", foreign_keys="Application.student_id", overlaps="student")
    events = relationship("Event", foreign_keys="Event.created_by", overlaps="admin")
    announcements = relationship("Announcement", foreign_keys="Announcement.created_by", overlaps="admin")
    notifications = relationship("Notification", foreign_keys="Notification.user_id", overlaps="user")
    resources = relationship("Resource", foreign_keys="Resource.created_by", overlaps="staff")


class StudentProfile(Base):
    __tablename__ = "student_profiles"

    student_id = Column(Integer, ForeignKey("users.user_id"), primary_key=True)
    educational_details = Column(Text, nullable=True)
    skills = Column(Text, nullable=True)
    resume_url = Column(String(255), nullable=True)
    interests = Column(Text, nullable=True)

    user = relationship("User", back_populates="student_profile")


class AlumniProfile(Base):
    __tablename__ = "alumni_profiles"

    alumni_id = Column(Integer, ForeignKey("users.user_id"), primary_key=True)
    company = Column(String(120), nullable=True, index=True)
    job_title = Column(String(120), nullable=True, index=True)
    mentorship_available = Column(Boolean, default=True, nullable=False)
    experience_summary = Column(Text, nullable=True)

    user = relationship("User", back_populates="alumni_profile")


class Connection(Base):
    __tablename__ = "connections"

    connection_id = Column(Integer, primary_key=True, index=True)
    requester_id = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    receiver_id = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    status = Column(String(20), default="pending", nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    requester = relationship("User", foreign_keys=[requester_id], overlaps="sent_connections")
    receiver = relationship("User", foreign_keys=[receiver_id], overlaps="received_connections")


class Message(Base):
    __tablename__ = "messages"

    message_id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    receiver_id = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    content = Column(Text, nullable=False)
    sent_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    is_read = Column(Boolean, default=False, nullable=False)

    sender = relationship("User", foreign_keys=[sender_id], overlaps="sent_messages")
    receiver = relationship("User", foreign_keys=[receiver_id], overlaps="received_messages")


class Internship(Base):
    __tablename__ = "internships"

    internship_id = Column(Integer, primary_key=True, index=True)
    posted_by = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    role_title = Column(String(150), nullable=False, index=True)
    company = Column(String(150), nullable=False, index=True)
    location = Column(String(120), nullable=True, index=True)
    duration = Column(String(100), nullable=True)
    stipend = Column(String(100), nullable=True)
    required_skills = Column(Text, nullable=True)
    seats = Column(Integer, default=1, nullable=False)
    deadline = Column(String(50), nullable=True)
    description = Column(Text, nullable=True)
    status = Column(String(50), default="Open", nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    alumni = relationship("User", foreign_keys=[posted_by], overlaps="internships")
    applications = relationship("Application", back_populates="internship")


class Application(Base):
    __tablename__ = "applications"

    application_id = Column(Integer, primary_key=True, index=True)
    internship_id = Column(Integer, ForeignKey("internships.internship_id"), nullable=False, index=True)
    student_id = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    cover_note = Column(Text, nullable=True)
    resume_url = Column(String(255), nullable=True)
    status = Column(String(30), default="Applied", nullable=False, index=True)
    applied_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    internship = relationship("Internship", back_populates="applications")
    student = relationship("User", foreign_keys=[student_id], overlaps="applications")


class Event(Base):
    __tablename__ = "events"

    event_id = Column(Integer, primary_key=True, index=True)
    created_by = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    title = Column(String(150), nullable=False)
    date = Column(String(50), nullable=True)
    location = Column(String(150), nullable=True)
    description = Column(Text, nullable=True)
    category = Column(String(50), default="event", nullable=False)
    target_audience = Column(String(50), default="all", nullable=False)  # "all", "student", "alumni"
    has_document = Column(Boolean, default=False, nullable=False)
    has_photos = Column(Boolean, default=False, nullable=False)
    document_url = Column(String(255), nullable=True)
    photo_url = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    admin = relationship("User", foreign_keys=[created_by], overlaps="events")


class Announcement(Base):
    __tablename__ = "announcements"

    announcement_id = Column(Integer, primary_key=True, index=True)
    created_by = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    admin = relationship("User", foreign_keys=[created_by], overlaps="announcements")


class Notification(Base):
    __tablename__ = "notifications"

    noti_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    type = Column(String(50), nullable=True)  # "message", "connection", "event"
    message = Column(String(255), nullable=False)
    is_read = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    user = relationship("User", foreign_keys=[user_id], overlaps="notifications")


class Resource(Base):
    __tablename__ = "resources"

    resource_id = Column(Integer, primary_key=True, index=True)
    created_by = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    resource_type = Column(String(50), nullable=False)  # 'document', 'link'
    url = Column(String(255), nullable=False)
    target_audience = Column(String(50), default="all", nullable=False)  # "all", "student", "alumni"
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    staff = relationship("User", foreign_keys=[created_by], overlaps="resources")


class BroadcastLog(Base):
    __tablename__ = "broadcast_logs"

    log_id = Column(Integer, primary_key=True, index=True)
    sent_by = Column(Integer, ForeignKey("users.user_id"), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    message = Column(Text, nullable=False)
    target_role = Column(String(50), nullable=False)  # "all", "student", "alumni", "staff"
    recipient_count = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    sender = relationship("User", foreign_keys=[sent_by], overlaps="resources")
