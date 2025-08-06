@echo off
echo ===============================================
echo    DSHI Flask API Server Starting...
echo ===============================================
echo Port: 5001
echo Debug Log: flask_debug.log
echo.

REM Stop any existing servers first
echo Cleaning up existing processes...
wmic process where "name='python.exe'" delete >nul 2>&1
echo Waiting 3 seconds for cleanup...
timeout /t 3 /nobreak >nul

echo.
echo Starting Flask API server...
cd /d "E:\DSHI_RPA\APP"
python flask_server.py

echo.
echo Flask server stopped.
pause