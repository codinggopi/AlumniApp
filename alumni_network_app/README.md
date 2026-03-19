# Alumni Network App (Flutter)

The mobile application for students and alumni, built with **Flutter** and **Provider** for state management.

## Features

- **Modern UI**: Clean and intuitive interface designed for networking.
- **Multi-Role Support**: Different dashboards and features for Students vs. Alumni.
- **Searchable Directory**: Find alumni by department, city, or company.
- **Internship Management**: In-app application tracking and posting for alumni.
- **Real-time Messaging**: Chat directly with mentors and peers.
- **Adaptive Design**: Responsive screens for various device sizes.

## Getting Started

### 1. Configuration
Update the `baseUrl` in `lib/services/api_service.dart` to match your server's local IP address:
```dart
static const String baseUrl = 'http://[IP_ADDRESS]';
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run the App
```bash
flutter run
```

## Project Directory Structure

- `lib/models/`: Data models for User, Internship, Message, etc.
- `lib/services/`: API communication services.
- `lib/providers/`: State management (Auth, etc.).
- `lib/screens/`: 
  - `auth/`: Login, Register, OTP screens.
  - `directory/`: Alumni listing and profiles.
  - `internships/`: Listing, detail, and posting screens.
  - `chat/`: Chat rooms.
  - `events/`: Event feed.
- `lib/widgets/`: Reusable UI components.
