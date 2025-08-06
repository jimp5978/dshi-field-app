@echo off
echo ===============================================
echo    DSHI Sinatra Web Server Starting...
echo ===============================================
echo Port: 5008
echo Debug Log: test_app\debug.log
echo.

REM Stop any existing servers first
echo Cleaning up existing processes...
wmic process where "name='ruby.exe'" delete >nul 2>&1
echo Waiting 3 seconds for cleanup...
timeout /t 3 /nobreak >nul

echo.
echo Starting Sinatra Web server...
cd /d "E:\DSHI_RPA\APP\test_app"
ruby app.rb -p 5008

echo.
echo Sinatra server stopped.
pause