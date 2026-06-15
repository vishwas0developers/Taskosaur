@echo off
setlocal enabledelayedexpansion
title PostgreSQL Migration Tool

REM Default values
set "DB_HOST="
set "DB_PORT="

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
echo       PostgreSQL Migration Tool
echo ==========================================
echo.
echo Select Migration Target:
echo.
echo   1) Local (127.0.0.1:5433)
echo   2) Live Server (168.231.102.163:5433)
echo   3) Custom (Enter manually)
echo   4) Exit
echo.
set /p target_choice="Enter your choice (1-4): "

if "%target_choice%"=="1" goto set_local
if "%target_choice%"=="2" goto set_live
if "%target_choice%"=="3" goto set_custom
if "%target_choice%"=="4" goto exit
echo Invalid choice, try again.
pause
goto select_target

:set_local
set "DB_HOST=127.0.0.1"
set "DB_PORT=5433"
echo.
echo Target set to: Local (%DB_HOST%:%DB_PORT%)
goto main_menu

:set_live
set "DB_HOST=168.231.102.163"
set "DB_PORT=5433"
echo.
echo Target set to: Live Server (%DB_HOST%:%DB_PORT%)
goto main_menu

:set_custom
echo.
set /p "DB_HOST=Enter PostgreSQL Host: "
set /p "DB_PORT=Enter PostgreSQL Port [5433]: "
if "%DB_PORT%"=="" set "DB_PORT=5433"
echo.
echo Target set to: Custom (%DB_HOST%:%DB_PORT%)
goto main_menu

:main_menu
cls
echo ==========================================
echo   PostgreSQL Migration Tool
echo ==========================================
echo   Target: %DB_HOST%:%DB_PORT%
echo ==========================================
echo.
echo   1. Migrate All (Sub-apps + Core)
echo   2. Migrate Core Application Only
echo   3. Migrate Specific Sub-application
echo   4. List All Available Sub-applications
echo   5. Change Target Server
echo   6. Exit
echo ==========================================
echo.
set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" goto migrate_all
if "%choice%"=="2" goto migrate_core
if "%choice%"=="3" goto migrate_app
if "%choice%"=="4" goto list_apps
if "%choice%"=="5" goto select_target
if "%choice%"=="6" goto exit
echo Invalid choice, try again.
pause
goto main_menu

:migrate_all
echo.
echo Migrating everything to %DB_HOST%:%DB_PORT%...
python utility/postgres_migration.py --all --host %DB_HOST% --port %DB_PORT%
echo.
pause
goto main_menu

:migrate_core
echo.
echo Migrating Core Application to %DB_HOST%:%DB_PORT%...
python utility/postgres_migration.py --core --host %DB_HOST% --port %DB_PORT%
echo.
pause
goto main_menu

:migrate_app
echo.
echo Select sub-application(s) to migrate:
python utility/postgres_migration.py --list --host %DB_HOST% --port %DB_PORT%
echo.
echo You can enter multiple numbers separated by commas (e.g., 1,2,5)
echo.
set /p app_idx="Enter application number(s): "
echo Migrating application(s) !app_idx! to %DB_HOST%:%DB_PORT%...
python utility/postgres_migration.py --app-index "!app_idx!" --host %DB_HOST% --port %DB_PORT%
echo.
pause
goto main_menu

:list_apps
echo.
echo Available sub-applications:
python utility/postgres_migration.py --list --host %DB_HOST% --port %DB_PORT%
echo.
pause
goto main_menu

:exit
echo.
echo Exiting PostgreSQL Migration Tool.
exit /b 0