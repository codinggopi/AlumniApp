#!/bin/bash
echo "Starting Alumni Network App..."

# Start backend in background
cd backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
cd ..

# Wait for backend to initialize
sleep 3

# Start Flutter app
cd alumni_network_app
flutter run &
FLUTTER_PID=$!
cd ..

echo "Backend PID: $BACKEND_PID"
echo "Flutter PID: $FLUTTER_PID"
echo ""
echo "Press Ctrl+C to stop both..."

# Wait and handle Ctrl+C to kill both
trap "kill $BACKEND_PID $FLUTTER_PID 2>/dev/null; exit" INT
wait
