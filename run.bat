@echo off
echo Starting Alumni Network App...

:: Start backend in a new terminal window
start "Backend" cmd /k "cd backend && uvicorn main:app --reload --host 0.0.0.0 --port 8000"

:: Wait for backend to boot
timeout /t 3 /nobreak > nul

:: Start ngrok in a new terminal window
start "Ngrok" cmd /k "ngrok http 8000"

:: Wait for ngrok to initialize and get URL
echo Waiting for ngrok to start...
timeout /t 5 /nobreak > nul

:: Fetch ngrok public URL from its local API
for /f "delims=" %%i in ('powershell -command "(Invoke-WebRequest -Uri http://localhost:4040/api/tunnels | ConvertFrom-Json).tunnels[0].public_url"') do set NGROK_URL=%%i

if "%NGROK_URL%"=="" (
    echo ERROR: Could not get ngrok URL. Make sure ngrok is installed and running.
    pause
    exit /b 1
)

echo Ngrok URL: %NGROK_URL%


:: Start Flutter app
start "Flutter" cmd /k "cd alumni_network_app && flutter run"

echo All services started.
