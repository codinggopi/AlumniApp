# Alumni-Student Networking App v2.0

A comprehensive platform connecting students with alumni for mentorship, career guidance, and internship opportunities.

## Project Structure

- **`backend/`**: FastAPI-based server handling authentication, database management, and business logic.
- **`alumni_network_app/`**: Flutter mobile application providing a user-friendly interface for students and alumni.

## Core Features

- **Authentication**: Secure JWT-based login with OTP verification support.
- **User Profiles**: Specialized profiles for students and alumni with professional/academic details.
- **Alumni Directory**: Searchable and filterable directory of the college's alumni network.
- **Internship Board**: Post/browse internships and manage applications directly in the app.
- **Messaging**: Real-time messaging between students and alumni.
- **Events & Announcements**: A feed for college news and networking events.

## Getting Started

### 1. Prerequisites
- Python 3.8+
- Flutter SDK (latest stable)
- SQLite (for local development)
- PostgreSQL (recommended for production/Render)

### 2. Quick Start
For detailed instructions on each component, refer to their respective README files:
- [Backend Setup](./backend/README.md)
- [Flutter App Setup](./alumni_network_app/README.md)
- api for backend :   //static const String baseUrl = 'https://alumniapp-qths.onrender.com' and 'https://callum-unstigmatic-yappingly.ngrok-free.dev';

### Render Note
If backend is deployed on Render, use PostgreSQL via `DATABASE_URL`.  
Using local SQLite on Render can cause data reset on restart/redeploy.

---
*Created as part of the Alumni Association Network development.*
