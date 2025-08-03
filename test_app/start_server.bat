@echo off
chcp 65001 > nul
echo DSHI Sinatra Server Starting...
echo Port: 5008
echo External URL: http://203.251.108.199:5008
echo.

cd /d "e:\DSHI_RPA\APP\test_app"
ruby app.rb

pause