@echo off

REM Start Flask server in new window
start "DSHI Flask API Server" "%~dp0start_flask_server.bat"

REM Wait 2 seconds then start Sinatra server
timeout /t 2 /nobreak >nul

REM Start Sinatra server in new window
start "DSHI Sinatra Web Server" "%~dp0start_ruby_server.bat"

REM Exit immediately without showing any window
exit