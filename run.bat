@echo off
setlocal enabledelayedexpansion
title Moodify Mobile (Flutter)

:: ============================================================
::  Moodify Mobile - Flutter run script
::  - Environment 1: Production API (public backend, khong can backend local)
::  - Environment 2: Local API 10.0.2.2:8088 (Android emulator; tu dong
::    khoi dong backend local bang scripts\start-local-api.ps1)
::  Device: tu do android/ios; truyen device id lam tham so thu 1 de chi dinh
::  Vi du: run.bat emulator-5554
:: ============================================================

:: ===== Tim Flutter =====
set "FLUTTER=flutter"
where flutter >nul 2>nul
if errorlevel 1 (
    if exist "C:\flutter\bin\flutter.bat" (
        set "FLUTTER=C:\flutter\bin\flutter.bat"
    ) else (
        echo [LOI] Khong tim thay Flutter. Cai dat Flutter hoac them vao PATH.
        pause
        exit /b 1
    )
)

cd /d "%~dp0"

echo ============================================================
echo   Moodify Mobile - Flutter
echo ============================================================
echo.

echo [1/3] Tai dependency (flutter pub get)...
call %FLUTTER% pub get
if errorlevel 1 (
    echo [LOI] flutter pub get that bai.
    pause
    exit /b 1
)
echo.

:: ===== Chon moi truong API =====
echo [2/3] Chon moi truong API:
echo    1. Production - https://api.moodify.click/api (moi thiet bi)
echo    2. Local      - http://10.0.2.2:8088/api      (Android emulator,
echo                   tu dong khoi dong backend local, can MySQL/MongoDB)
choice /c 12 /n /m "Chon [1/2]: "
set "ENVCHOICE=%errorlevel%"
echo.

if "%ENVCHOICE%"=="1" (
    set "CONFIG=config\production.json"
) else (
    if not exist "config\local\development.json" (
        if not exist "config\local" mkdir "config\local"
        echo Tao config\local\development.json tu config\development.example.json...
        copy /y "config\development.example.json" "config\local\development.json" >nul
    )
    set "CONFIG=config\local\development.json"
    echo Kiem tra / khoi dong backend local (port 8088)...
    powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\start-local-api.ps1" -BackendPath "%~dp0..\Moodify-Backend-main"
    if errorlevel 1 (
        echo [LOI] Backend local chua san sang. Xem log trong build\local-api\.
        pause
        exit /b 1
    )
)
echo.

:: ===== Tim thiet bi =====
echo [3/3] Tim thiet bi Android/iOS...
set "DEVICE=%~1"
if not "%DEVICE%"=="" goto :devicepicked

for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "$d = & '%FLUTTER%' devices --machine 2>$null | ConvertFrom-Json | Where-Object { $_.targetPlatform -like 'android*' -or $_.targetPlatform -like 'ios*' } | Select-Object -First 1; if ($d) { $d.id }"`) do set "DEVICE=%%D"

:devicepicked
call %FLUTTER% devices
echo.
if "%DEVICE%"=="" (
    echo [LOI] Khong thay thiet bi Android/iOS.
    echo        - Mo Android Studio ^> Device Manager ^> chay emulator, hoac
    echo        - Ket noi dien thoai (bat USB debugging) roi chay lai.
    pause
    exit /b 1
)
echo Device id: %DEVICE%
set "INPUT="
set /p INPUT=Nhap device id khac (Enter = dung %DEVICE%): 
if not "%INPUT%"=="" set "DEVICE=%INPUT%"
echo.

echo ============================================================
echo   Dang chay: flutter run -d %DEVICE%
echo              --dart-define-from-file=%CONFIG%
echo   Thoat app: nhan q trong cua so nay
echo ============================================================
call %FLUTTER% run -d %DEVICE% --dart-define-from-file=%CONFIG%
echo.
echo App da thoat.
pause
