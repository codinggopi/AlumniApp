# Alumni App Backend

The backend server for the Alumni-Student Networking platform, built with **FastAPI** and **SQLAlchemy**.

## Features

- **JWT Authentication**: Secure sessions for mobile and web clients.
- **OTP Verification**: Email-based OTP for registration and login.
- **RESTful API**: Endpoints for profiles, internships, connections, messaging, and more.
- **SQLite Database**: Lightweight and portable data storage.
- **Deployment Ready**: Configurable via environment variables.

## Getting Started

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Configure Environment
Create a `.env` file in this directory:
```bash
DATABASE_URL=sqlite:///./alumni_app.db
SECRET_KEY=change-this-in-prod
SMTP_EMAIL=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

### 3. Run the Server
To allow local network access (e.g., from a mobile device), run:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Visit `http://localhost:8000/docs` for the interactive API documentation (Swagger UI).

## API Modules

- `/auth`: Login, Register, OTP Verification.
- `/profile`: User profiles and resume uploads.
- `/alumni`: Searchable alumni directory.
- `/internships`: Internship postings and applications.
- `/messages`: One-to-one chat functionality.
- `/events` & `/announcements`: College news and event management.
