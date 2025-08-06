@echo off
echo Starting DSHI Field Pad Server...
echo.
echo Choose startup method:
echo 1. Direct execution (python flask_server.py)
echo 2. Flask CLI (flask run)
echo.
set /p choice="Enter your choice (1 or 2): "

if "%choice%"=="1" (
    echo Starting with direct execution...
    python flask_server.py
) else if "%choice%"=="2" (
    echo Starting with Flask CLI...
    set FLASK_APP=app.py
    set FLASK_ENV=development
    flask run --host 0.0.0.0 --port 5001
) else (
    echo Invalid choice. Starting with default method...
    python flask_server.py
)

pause