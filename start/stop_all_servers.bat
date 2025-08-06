@echo off
echo ===============================================
echo    DSHI Server Shutdown System
echo ===============================================
echo.

echo [1/4] Checking running servers...
echo Checking Flask API Server (Port 5001)...
netstat -an | findstr ":5001" >nul
if %errorlevel%==0 (
    echo [FOUND] Flask API Server running on port 5001
    set FLASK_RUNNING=1
) else (
    echo [OK] Flask API Server not running
    set FLASK_RUNNING=0
)

echo Checking Sinatra Web Server (Port 5008)...
netstat -an | findstr ":5008" >nul
if %errorlevel%==0 (
    echo [FOUND] Sinatra Web Server running on port 5008
    set SINATRA_RUNNING=1
) else (
    echo [OK] Sinatra Web Server not running
    set SINATRA_RUNNING=0
)

echo.
echo [2/4] Graceful shutdown attempt...
echo Sending CTRL+C to running processes...
timeout /t 2 /nobreak >nul

echo.
echo [3/4] Force terminating processes...
echo Terminating Python processes (Flask API)...
wmic process where "name='python.exe'" delete >nul 2>&1
if %errorlevel%==0 (
    echo [OK] Python processes terminated
) else (
    echo [INFO] No Python processes found
)

echo Terminating Ruby processes (Sinatra Web)...
wmic process where "name='ruby.exe'" delete >nul 2>&1
if %errorlevel%==0 (
    echo [OK] Ruby processes terminated
) else (
    echo [INFO] No Ruby processes found
)

echo.
echo [4/4] Final verification and cleanup...
echo Waiting 3 seconds for cleanup...
timeout /t 3 /nobreak >nul

echo Checking port 5001 (Flask API)...
netstat -an | findstr ":5001" >nul
if %errorlevel%==0 (
    echo [WARNING] Port 5001 still in use - may need manual cleanup
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5001"') do (
        taskkill /f /pid %%a >nul 2>&1
    )
    echo [RETRY] Forced cleanup attempted
) else (
    echo [OK] Port 5001 is free
)

echo Checking port 5008 (Sinatra Web)...
netstat -an | findstr ":5008" >nul
if %errorlevel%==0 (
    echo [WARNING] Port 5008 still in use - may need manual cleanup
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5008"') do (
        taskkill /f /pid %%a >nul 2>&1
    )
    echo [RETRY] Forced cleanup attempted
) else (
    echo [OK] Port 5008 is free
)

echo.
echo Cleanup temporary files...
if exist "E:\DSHI_RPA\APP\temp\" (
    del /q "E:\DSHI_RPA\APP\temp\*" >nul 2>&1
    echo [OK] Temporary files cleaned
)

echo.
echo ===============================================
echo Server shutdown complete!
echo Flask API (5001): STOPPED
echo Sinatra Web (5008): STOPPED
echo ===============================================
echo.
echo Press any key to exit...
pause