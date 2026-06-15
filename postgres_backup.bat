@echo off
setlocal enabledelayedexpansion
title PostgreSQL Live-to-Local Backup Tool

REM Default values
set "DB_HOST="
set "DB_PORT="
set "BACKUP_DIR=Backup\Docker_Full_DB_BP"

REM Activate virtual environment
call "%~dp0venv\Scripts\activate.bat" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Virtual environment not found. Please run setup.bat first.
    pause
    exit /b 1
)

:select_target
cls
echo ==========================================
echo       PostgreSQL Backup Tool
echo ==========================================
echo.
echo Select Target Host:
echo.
echo   1) Local (127.0.0.1:5433)
echo   2) Live Server (168.231.102.163:5433)
echo   3) Custom (Enter manually)
echo   4) Exit
echo.
set /p target_choice="Enter your choice (1-4): "

if "%target_choice%"=="1" (
    set "DB_HOST=127.0.0.1"
    set "DB_PORT=5433"
    goto main_menu
)
if "%target_choice%"=="2" (
    set "DB_HOST=168.231.102.163"
    set "DB_PORT=5433"
    goto main_menu
)
if "%target_choice%"=="3" (
    echo.
    set /p "DB_HOST=Enter PostgreSQL Host: "
    set /p "DB_PORT=Enter PostgreSQL Port [5433]: "
    if "%DB_PORT%"=="" set "DB_PORT=5433"
    goto main_menu
)
if "%target_choice%"=="4" goto exit
echo Invalid choice, try again.
pause
goto select_target

:main_menu
cls
echo ==========================================
echo   PostgreSQL Backup Tool
echo ==========================================
echo   Target: %DB_HOST%:%DB_PORT%
echo ==========================================
echo.
echo   1. Backup All (Sub-apps + Core)
echo   2. Backup Core Application Only
echo   3. Backup Specific Sub-application
echo   4. List All Available Sub-applications
echo   5. Change Target Server
echo   6. Exit
echo ==========================================
echo.
set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" goto backup_all
if "%choice%"=="2" goto backup_core
if "%choice%"=="3" goto backup_app
if "%choice%"=="4" goto list_apps
if "%choice%"=="5" goto select_target
if "%choice%"=="6" goto exit
echo Invalid choice, try again.
pause
goto main_menu

:backup_all
echo.
echo Starting full SQL zip backup from %DB_HOST%:%DB_PORT%...
python utility/postgres_backup.py --all --host %DB_HOST% --port %DB_PORT%
echo.
pause
goto main_menu

:backup_core
echo.
echo Starting Core application SQL zip backup from %DB_HOST%:%DB_PORT%...
python utility/postgres_backup.py --core --host %DB_HOST% --port %DB_PORT%
echo.
pause
goto main_menu

:backup_app
echo.
echo Select sub-application(s) to backup (comma-separated indices):
python utility/postgres_backup.py --list
echo.
set /p app_idx="Enter application number(s): "
echo Starting SQL zip backup for !app_idx! from %DB_HOST%:%DB_PORT%...
python utility/postgres_backup.py --app-index "!app_idx!" --host %DB_HOST% --port %DB_PORT%
echo.
pause
goto main_menu

:list_apps
echo.
echo Available sub-applications:
python utility/postgres_backup.py --list
echo.
pause
goto main_menu

:exit
echo.
echo Exiting PostgreSQL Backup Tool.
exit /b 0
