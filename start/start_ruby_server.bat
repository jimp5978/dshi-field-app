@echo off
echo ===============================================
echo    DSHI Sinatra Web Server Starting...
echo ===============================================
echo Port: 5008 (External Access Enabled)
echo Debug Log: test_app\debug.log
echo.

cd /d "e:\DSHI_RPA\APP\test_app"
ruby app.rb

echo.
echo Sinatra server stopped.
pause