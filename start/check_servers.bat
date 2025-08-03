@echo off
echo ===============================================
echo    DSHI Server Status Check
echo ===============================================
echo.

echo Checking Flask API Server (Port 5001)...
netstat -an | findstr ":5001" >nul
if %errorlevel%==0 (
    echo [OK] Flask API Server: RUNNING on port 5001
) else (
    echo [NO] Flask API Server: NOT RUNNING
)

echo.
echo Checking Sinatra Web Server (Port 5008)...
netstat -an | findstr ":5008" >nul
if %errorlevel%==0 (
    echo [OK] Sinatra Web Server: RUNNING on port 5008
) else (
    echo [NO] Sinatra Web Server: NOT RUNNING
)

echo.
echo Checking Python processes...
tasklist | findstr "python.exe" >nul
if %errorlevel%==0 (
    echo Python processes found:
    tasklist | findstr "python.exe"
) else (
    echo No Python processes running
)

echo.
echo Checking Ruby processes...
tasklist | findstr "ruby.exe" >nul
if %errorlevel%==0 (
    echo Ruby processes found:
    tasklist | findstr "ruby.exe"
) else (
    echo No Ruby processes running
)

echo.
echo ===============================================
echo URLs:
echo Flask API: http://localhost:5001
echo Sinatra Web: http://localhost:5008
echo External Access: http://203.251.108.199:5008
echo ===============================================
echo.
echo Press any key to exit...
pause