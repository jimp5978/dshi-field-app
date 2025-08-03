@echo off
echo ===============================================
echo    DSHI Flask API Server Starting...
echo ===============================================
echo Port: 5001
echo Debug Log: flask_debug.log
echo.

cd /d "e:\DSHI_RPA\APP"
python flask_server.py

echo.
echo Flask server stopped.
pause