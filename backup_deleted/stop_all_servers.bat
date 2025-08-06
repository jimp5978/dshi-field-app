@echo off
echo ===============================================
echo    DSHI Server Shutdown
echo ===============================================
echo.

echo Stopping all Python processes (Flask)...
wmic process where "name='python.exe'" delete >nul 2>&1
if %errorlevel%==0 (
    echo ✅ Python processes stopped
) else (
    echo ⚠️  No Python processes were running
)

echo.
echo Stopping all Ruby processes (Sinatra)...
wmic process where "name='ruby.exe'" delete >nul 2>&1
if %errorlevel%==0 (
    echo ✅ Ruby processes stopped
) else (
    echo ⚠️  No Ruby processes were running
)

echo.
echo Checking final status...
timeout /t 2 /nobreak >nul

netstat -an | findstr ":5001" >nul
if %errorlevel%==0 (
    echo ⚠️  Port 5001 still in use
) else (
    echo ✅ Port 5001 freed
)

netstat -an | findstr ":5008" >nul
if %errorlevel%==0 (
    echo ⚠️  Port 5008 still in use
) else (
    echo ✅ Port 5008 freed
)

echo.
echo ===============================================
echo All DSHI servers stopped.
echo ===============================================
echo.
pause