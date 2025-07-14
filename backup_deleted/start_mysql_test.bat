@echo off
echo ================================================================
echo DSHI Field Pad App - MySQL 연동 버전 테스트
echo ================================================================
echo.
echo 실제 MySQL 데이터베이스 (373개 Assembly 데이터) 연동 테스트
echo.

echo 1. MySQL 연결 테스트 중...
cd /d E:\DSHI_RPA\APP
python simple_mysql_test.py

echo.
echo 2. MySQL Flask 서버 시작중...
start "MySQL Flask Server" cmd /k "python mysql_flask_server.py"

echo.
echo 3. 5초 대기 (서버 초기화 시간)...
timeout /t 5 /nobreak > nul

echo.
echo 4. Flutter 앱 실행 중...
cd /d E:\DSHI_RPA\APP\field_pad_app
flutter run -d windows

echo.
echo ================================================================
echo 테스트 완료!
echo.
echo 테스트 계정:
echo   admin / admin123 (Level 5 - 전체 관리)
echo   test_level1 / test123 (Level 1 - 외부업체)
echo   test_level3 / test123 (Level 3 - DSHI 현장)
echo.
echo 검색 테스트:
echo   "RF" 입력 - RF-031 시리즈 확인
echo   "TN1" 입력 - TN1 시리즈 확인
echo ================================================================
pause
