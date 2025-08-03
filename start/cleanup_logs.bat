@echo off
echo ===============================================
echo    DSHI Debug Log Cleanup Tool
echo ===============================================
echo.
echo 1. Clear all logs (Flask + Ruby)
echo 2. Archive logs (backup then clear)
echo 3. Clear old logs (keep last 1000 lines)
echo 4. View log sizes
echo 5. Exit
echo.

set /p choice="Select option (1-5): "

if "%choice%"=="1" (
    echo.
    echo Clearing all debug logs...
    if exist "e:\DSHI_RPA\APP\flask_debug.log" (
        echo. > "e:\DSHI_RPA\APP\flask_debug.log"
        echo [OK] Flask debug log cleared
    )
    if exist "e:\DSHI_RPA\APP\test_app\debug.log" (
        echo. > "e:\DSHI_RPA\APP\test_app\debug.log"
        echo [OK] Ruby debug log cleared
    )
    echo All logs cleared!
    
) else if "%choice%"=="2" (
    echo.
    echo Archiving logs...
    set timestamp=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%
    set timestamp=%timestamp: =0%
    
    if exist "e:\DSHI_RPA\APP\flask_debug.log" (
        copy "e:\DSHI_RPA\APP\flask_debug.log" "e:\DSHI_RPA\APP\logs\flask_debug_%timestamp%.log" >nul
        echo. > "e:\DSHI_RPA\APP\flask_debug.log"
        echo [OK] Flask log archived as flask_debug_%timestamp%.log
    )
    if exist "e:\DSHI_RPA\APP\test_app\debug.log" (
        copy "e:\DSHI_RPA\APP\test_app\debug.log" "e:\DSHI_RPA\APP\logs\debug_%timestamp%.log" >nul
        echo. > "e:\DSHI_RPA\APP\test_app\debug.log"
        echo [OK] Ruby log archived as debug_%timestamp%.log
    )
    echo Logs archived and cleared!
    
) else if "%choice%"=="3" (
    echo.
    echo Keeping last 1000 lines of each log...
    if exist "e:\DSHI_RPA\APP\flask_debug.log" (
        powershell -Command "Get-Content 'e:\DSHI_RPA\APP\flask_debug.log' | Select-Object -Last 1000 | Set-Content 'e:\DSHI_RPA\APP\flask_debug_temp.log'"
        move "e:\DSHI_RPA\APP\flask_debug_temp.log" "e:\DSHI_RPA\APP\flask_debug.log" >nul
        echo [OK] Flask log trimmed to last 1000 lines
    )
    if exist "e:\DSHI_RPA\APP\test_app\debug.log" (
        powershell -Command "Get-Content 'e:\DSHI_RPA\APP\test_app\debug.log' | Select-Object -Last 1000 | Set-Content 'e:\DSHI_RPA\APP\test_app\debug_temp.log'"
        move "e:\DSHI_RPA\APP\test_app\debug_temp.log" "e:\DSHI_RPA\APP\test_app\debug.log" >nul
        echo [OK] Ruby log trimmed to last 1000 lines
    )
    echo Logs trimmed!
    
) else if "%choice%"=="4" (
    echo.
    echo Current log file sizes:
    if exist "e:\DSHI_RPA\APP\flask_debug.log" (
        for %%A in ("e:\DSHI_RPA\APP\flask_debug.log") do echo Flask debug log: %%~zA bytes
    ) else (
        echo Flask debug log: Not found
    )
    if exist "e:\DSHI_RPA\APP\test_app\debug.log" (
        for %%A in ("e:\DSHI_RPA\APP\test_app\debug.log") do echo Ruby debug log: %%~zA bytes
    ) else (
        echo Ruby debug log: Not found
    )
    
) else if "%choice%"=="5" (
    exit /b
) else (
    echo Invalid choice. Please try again.
    timeout /t 2 /nobreak >nul
    goto start
)

echo.
echo Press any key to continue...
pause >nul