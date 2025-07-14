@echo off
echo ================================================
echo DSHI Field Pad App 테스트 시작
echo ================================================
echo.

echo 1. Flask 서버 시작중...
cd /d E:\DSHI_RPA\APP
start "Flask Server" cmd /k "python simple_flask_server.py"

echo.
echo 2. 3초 대기 (서버 시작 시간)...
timeout /t 3 /nobreak > nul

echo.
echo 3. Flutter 앱 실행 중...
cd /d E:\DSHI_RPA\APP\field_pad_app
flutter run -d windows

echo.
echo 테스트 완료!
pause
