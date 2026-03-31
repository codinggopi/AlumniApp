# Alumni App Backend

The backend server for the Alumni-Student Networking platform, built with **FastAPI** and **SQLAlchemy**.

## Features

- **JWT Authentication**: Secure sessions for mobile and web clients.
- **OTP Verification**: Email-based OTP for registration and login.
- **RESTful API**: Endpoints for profiles, internships, connections, messaging, and more.
- **Database Support**: Local SQLite for development, PostgreSQL for production (Render-ready).
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

For production (Render), use a PostgreSQL URL:
```bash
DATABASE_URL=postgresql://<user>:<password>@<host>:<port>/<database>
```

### 3. Run the Server
To allow local network access (e.g., from a mobile device), run:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Visit `http://localhost:8000/docs` for the interactive API documentation (Swagger UI).

## Render Deployment (Persistent Data)

If you use SQLite on Render, data is stored on ephemeral disk and can reset after restart/redeploy.

1. Create a **Render PostgreSQL** instance.
2. In your backend Render service, set `DATABASE_URL` to that database's **Internal Database URL**.
3. Keep `SECRET_KEY`, `SMTP_EMAIL`, and `SMTP_PASSWORD` in Render environment variables.
4. Redeploy the backend service.

Notes:
- This project auto-creates tables on startup (`init_db()`), so no extra migration step is required for first deploy.
- Avoid any reset scripts in startup commands.

## API Modules

- `/auth`: Login, Register, OTP Verification.
- `/profile`: User profiles and resume uploads.
- `/alumni`: Searchable alumni directory.
- `/internships`: Internship postings and applications.
- `/messages`: One-to-one chat functionality.
- `/events` & `/announcements`: College news and event management.
