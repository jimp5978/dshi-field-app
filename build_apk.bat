@echo off
echo Building DSHI Field Pad APK with dynamic server configuration...
cd dshi_field_app

echo.
echo Step 1: Getting Flutter dependencies...
flutter pub get

echo.
echo Step 2: Building APK...
flutter build apk --release

echo.
echo Build complete! APK location:
echo %cd%\build\app\outputs\flutter-apk\app-release.apk

echo.
echo You can now install this APK on your Android device.
echo The app will allow you to configure the server URL dynamically.

pause