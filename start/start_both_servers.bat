@echo off
echo ===============================================
echo    DSHI Integrated Server System
echo ===============================================
echo Starting Flask API + Sinatra Web servers
echo.

REM Stop any existing servers first
echo Cleaning up existing processes...
wmic process where "name='python.exe'" delete >nul 2>&1
wmic process where "name='ruby.exe'" delete >nul 2>&1
echo Waiting 5 seconds for cleanup...
timeout /t 5 /nobreak >nul

echo.
echo Starting Flask API Server in new window...
start "DSHI Flask API Server" "%~dp0start_flask_server.bat"

echo Waiting 3 seconds for Flask to initialize...
timeout /t 3 /nobreak >nul

echo Starting Sinatra Web Server in new window...
start "DSHI Sinatra Web Server" "%~dp0start_ruby_server.bat"

echo.
echo ===============================================
echo Both servers started successfully!
echo ===============================================
echo Flask API:     http://localhost:5001
echo Sinatra Web:   http://localhost:5008
echo.
echo Servers are running in background windows.
echo This window will close in 3 seconds...
timeout /t 3 /nobreak >nul
exit