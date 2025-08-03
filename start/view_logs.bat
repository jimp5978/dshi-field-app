@echo off
echo ===============================================
echo    DSHI Server Log Viewer
echo ===============================================
echo.
echo 1. Flask Debug Log (flask_debug.log)
echo 2. Ruby Debug Log (test_app\debug.log) 
echo 3. Flask Access Log (flask_test.log)
echo 4. Both Debug Logs (side by side)
echo 5. Exit
echo.

set /p choice="Select option (1-5): "

if "%choice%"=="1" (
    echo.
    echo Opening Flask Debug Log...
    if exist "e:\DSHI_RPA\APP\flask_debug.log" (
        start notepad "e:\DSHI_RPA\APP\flask_debug.log"
    ) else (
        echo ❌ Flask debug log not found
    )
) else if "%choice%"=="2" (
    echo.
    echo Opening Ruby Debug Log...
    if exist "e:\DSHI_RPA\APP\test_app\debug.log" (
        start notepad "e:\DSHI_RPA\APP\test_app\debug.log"
    ) else (
        echo ❌ Ruby debug log not found
    )
) else if "%choice%"=="3" (
    echo.
    echo Opening Flask Access Log...
    if exist "e:\DSHI_RPA\APP\flask_test.log" (
        start notepad "e:\DSHI_RPA\APP\flask_test.log"
    ) else (
        echo ❌ Flask access log not found
    )
) else if "%choice%"=="4" (
    echo.
    echo Opening both debug logs...
    if exist "e:\DSHI_RPA\APP\flask_debug.log" (
        start notepad "e:\DSHI_RPA\APP\flask_debug.log"
    )
    if exist "e:\DSHI_RPA\APP\test_app\debug.log" (
        start notepad "e:\DSHI_RPA\APP\test_app\debug.log"
    )
) else if "%choice%"=="5" (
    exit /b
) else (
    echo Invalid choice. Please try again.
    timeout /t 2 /nobreak >nul
    goto :start
)

echo.
pause