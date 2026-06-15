@echo off
SetLocal EnableDelayedExpansion
title Flask Bot Manager Docker Full Deployment

REM Enable Docker BuildKit for modern caching features
set DOCKER_BUILDKIT=1
set COMPOSE_DOCKER_CLI_BUILD=1

REM Activate virtual environment (required for Python utility scripts)
call "%~dp0venv\Scripts\activate.bat" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Virtual environment not found. Please run setup.bat first.
    pause
    exit /b 1
)

REM =====================================================
REM MAIN MENU - Select Deployment Mode
REM =====================================================

echo =====================================================
echo   Flask Bot Manager Docker Full Deployment Script
echo =====================================================
echo.
echo Please select deployment mode:
echo.
echo   1) Full Deployment (Build -^> Push -^> Deploy -^> Cleanup)
echo   2) Build and Push Only (Phase 1)
echo   3) Remote Deploy Only (Phase 2)
echo   4) Remote Cleanup Only (Phase 3)
echo   5) Remote Deploy + Cleanup (Phase 2 + 3)
echo   6) Full Deployment [NO CACHE] (Build --no-cache -^> Push -^> Deploy -^> Cleanup)
echo.

choice /C 123456 /N /M "Select option [1-6]:"

IF %ERRORLEVEL% EQU 1 GOTO MODE_FULL
IF %ERRORLEVEL% EQU 2 GOTO MODE_BUILD
IF %ERRORLEVEL% EQU 3 GOTO MODE_DEPLOY
IF %ERRORLEVEL% EQU 4 GOTO MODE_CLEANUP
IF %ERRORLEVEL% EQU 5 GOTO MODE_DEPLOY_CLEANUP
IF %ERRORLEVEL% EQU 6 GOTO MODE_FULL_NO_CACHE

REM Fallback
echo Invalid choice. Exiting...
pause
exit /b 1

:MODE_FULL
set "RUN_PHASE_1=1"
set "RUN_PHASE_2=1"
set "RUN_PHASE_3=1"
set "MODE_LABEL=Full Deployment"
set "USE_NO_CACHE=0"
GOTO START_EXECUTION

:MODE_BUILD
set "RUN_PHASE_1=1"
set "RUN_PHASE_2=0"
set "RUN_PHASE_3=0"
set "MODE_LABEL=Build and Push Only"
set "USE_NO_CACHE=0"
GOTO START_EXECUTION

:MODE_DEPLOY
set "RUN_PHASE_1=0"
set "RUN_PHASE_2=1"
set "RUN_PHASE_3=0"
set "MODE_LABEL=Remote Deploy Only"
set "USE_NO_CACHE=0"
GOTO START_EXECUTION

:MODE_CLEANUP
set "RUN_PHASE_1=0"
set "RUN_PHASE_2=0"
set "RUN_PHASE_3=1"
set "MODE_LABEL=Remote Cleanup Only"
set "USE_NO_CACHE=0"
GOTO START_EXECUTION

:MODE_DEPLOY_CLEANUP
set "RUN_PHASE_1=0"
set "RUN_PHASE_2=1"
set "RUN_PHASE_3=1"
set "MODE_LABEL=Remote Deploy + Cleanup"
set "USE_NO_CACHE=0"
GOTO START_EXECUTION

:MODE_FULL_NO_CACHE
set "RUN_PHASE_1=1"
set "RUN_PHASE_2=1"
set "RUN_PHASE_3=1"
set "MODE_LABEL=Full Deployment [NO CACHE]"
set "USE_NO_CACHE=1"
GOTO START_EXECUTION

REM =====================================================
REM START EXECUTION
REM =====================================================
:START_EXECUTION

echo.
echo Selected Mode: !MODE_LABEL!
echo.

REM =====================================================
REM PRE-DEPLOYMENT: DAILY LIVE POSTGRES BACKUP
REM =====================================================
echo.
echo =====================================================
echo   PRE-DEPLOYMENT: CHECKING DAILY BACKUP
echo =====================================================
set "BACKUP_DIR=D:\AI_Tools\1-Apps\Flask_Bot_Manager\Backup\Docker_Full_DB_BP"

REM Get today's date in YYYYMMDD format
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "TODAY=!dt:~0,8!"

echo Ensuring backup directory exists: !BACKUP_DIR!
if not exist "!BACKUP_DIR!" mkdir "!BACKUP_DIR!"

REM Check if a backup for today already exists
set "BACKUP_EXISTS=0"
for %%F in ("!BACKUP_DIR!\full_live_db_backup_!TODAY!_*.zip") do (
    set "BACKUP_EXISTS=1"
)

if "!BACKUP_EXISTS!"=="1" (
    echo.
    echo [INFO] A database backup for today ^(!TODAY!^) already exists.
    echo [INFO] Skipping redundant backup step.
) else (
    echo.
    echo [INFO] No backup found for today. Starting pre-deployment backup...
    
    REM Define Live Target IP/Port (matching standard settings)
    set "LIVE_DB_HOST=168.231.102.163" 
    set "LIVE_DB_PORT=5433"

    echo Connecting to live PostgreSQL server [!LIVE_DB_HOST!:!LIVE_DB_PORT!]
    python utility\postgres_backup.py --all --host !LIVE_DB_HOST! --port !LIVE_DB_PORT! --backup-dir "!BACKUP_DIR!"

    IF !ERRORLEVEL! NEQ 0 (
        echo.
        echo WARNING: Pre-deployment database backup failed or completed with errors.
        echo Proceeding with deployment ^(daily backup is not mandatory^)...
    ) else (
        echo Pre-deployment backup generated successfully.
    )
)
echo.

REM =====================================================
REM PHASE 1: BUILD AND PUSH (from Docker_setup.bat)
REM =====================================================

IF "!RUN_PHASE_1!"=="1" GOTO PHASE_1_EXECUTE
GOTO PHASE_1_SKIP

:PHASE_1_EXECUTE
echo.
echo =====================================================
echo   PHASE 1: DOCKER BUILD AND PUSH
echo =====================================================
echo --- Flask Bot Manager Docker Setup ---

REM --- Select deployment option ---
echo.
echo Please choose a deployment option:
echo   1) Push image only to Docker Hub.
echo   2) Push image to Docker Desktop + Docker Hub.
echo.

choice /C 12 /N /M "Select option [1-2]:"
IF %ERRORLEVEL% EQU 1 (
    set "RUN_LOCAL=0"
    set "DEPLOYMENT_LABEL=Docker Hub only"
) ELSE (
    set "RUN_LOCAL=1"
    set "DEPLOYMENT_LABEL=Docker Desktop + Docker Hub"
)
echo Selected deployment mode: !DEPLOYMENT_LABEL!

REM --- Docker Check & Auto-Start ---
echo.
echo Checking for Docker engine...
docker info >nul 2>&1
IF !ERRORLEVEL! NEQ 0 GOTO DOCKER_START
GOTO DOCKER_READY

:DOCKER_START
echo.
echo Docker is not running. Attempting to start Docker Desktop...
set "DOCKER_PATH=C:\Program Files\Docker\Docker\Docker Desktop.exe"

IF NOT EXIST "!DOCKER_PATH!" (
    echo ERROR: Docker Desktop executable not found at: !DOCKER_PATH!
    echo Please ensure Docker Desktop is installed.
    pause
    exit /b 1
)

echo Starting Docker Desktop...
start "" "!DOCKER_PATH!"
echo Waiting for Docker to start...
set /a MAX_RETRIES=30
set /a RETRY_COUNT=0

:WAIT_LOOP
set /a RETRY_COUNT+=1
echo Attempt !RETRY_COUNT! of !MAX_RETRIES!...
timeout /t 5 >nul

docker info >nul 2>&1
IF !ERRORLEVEL! EQU 0 GOTO DOCKER_READY

IF !RETRY_COUNT! GEQ !MAX_RETRIES! (
    echo.
    echo ERROR: Timeout waiting for Docker to start.
    echo Please start Docker Desktop manually and try again.
    pause
    exit /b 1
)

GOTO WAIT_LOOP

:DOCKER_READY
echo.

REM --- Check and Prepare .env file ---
echo.
IF NOT EXIST .env (
    echo .env file not found. Copying from .env.example...
    copy .env.example .env >nul
    echo IMPORTANT: A new .env file has been created. Please configure it.
)

REM --- Check Docker Credentials ---
set "D_USER_VAL="
for /f "tokens=2 delims==" %%a in ('findstr /b "DOCKER_USERNAME=" .env 2^>nul') do set "D_USER_VAL=%%a"

if defined D_USER_VAL set "D_USER_VAL=!D_USER_VAL: =!"

IF "!D_USER_VAL!"=="" GOTO DOCKER_LOGIN_SETUP
GOTO LOAD_CREDENTIALS

:DOCKER_LOGIN_SETUP
echo.
echo ---------------------------------------------------------------
echo  Docker Hub Setup
echo ---------------------------------------------------------------
echo  Please enter your Docker Hub Username.
echo ---------------------------------------------------------------

set /p "IN_USER=Docker Username: "

echo.
echo Launching Docker Login...
docker login -u !IN_USER!

IF !ERRORLEVEL! NEQ 0 (
    echo ERROR: Docker Login Failed.
    pause
    exit /b 1
)

echo Updating .env configuration...
python utility/docker_hub_manager.py !IN_USER!

for /f "tokens=2 delims==" %%a in ('findstr /b "DOCKER_USERNAME=" .env') do set "DOCKER_USERNAME=%%a"
for /f "tokens=2 delims==" %%a in ('findstr /b "DOCKER_REPO_NAME=" .env') do set "DOCKER_REPO_NAME=%%a"
GOTO CREDENTIALS_LOADED

:LOAD_CREDENTIALS
set "DOCKER_USERNAME=!D_USER_VAL!"
for /f "tokens=2 delims==" %%a in ('findstr /b "DOCKER_REPO_NAME=" .env') do set "DOCKER_REPO_NAME=%%a"

:CREDENTIALS_LOADED
set "DOCKER_USERNAME=!DOCKER_USERNAME: =!"
set "DOCKER_REPO_NAME=!DOCKER_REPO_NAME: =!"

REM --- Build and Push ---
echo.
IF "!USE_NO_CACHE!"=="1" (
    echo Building Docker image: !DOCKER_USERNAME!/!DOCKER_REPO_NAME!:latest with --no-cache...
    docker-compose build --no-cache
) ELSE (
    echo Building Docker image: !DOCKER_USERNAME!/!DOCKER_REPO_NAME!:latest...
    docker-compose build
)
IF !ERRORLEVEL! NEQ 0 (
    echo ERROR: Docker build failed.
    pause
    exit /b 1
)

echo.
echo Pushing image to Docker Hub...
docker-compose push
IF !ERRORLEVEL! NEQ 0 GOTO PUSH_RETRY
GOTO PUSH_SUCCESS

:PUSH_RETRY
echo.
echo ERROR: Docker push failed. Attempting re-login...
docker login -u !DOCKER_USERNAME!
docker-compose push
IF !ERRORLEVEL! NEQ 0 (
    echo Push failed again. Check your Docker Hub permissions.
    pause
    exit /b 1
)

:PUSH_SUCCESS
REM --- Conditional Local Run ---
IF "!RUN_LOCAL!"=="1" GOTO RUN_LOCAL
GOTO SKIP_LOCAL_RUN

:RUN_LOCAL
echo.
echo Starting Application locally...
docker-compose up -d --force-recreate
IF !ERRORLEVEL! NEQ 0 (
    echo ERROR: Failed to start containers.
    pause
    exit /b 1
)
echo Access at: http://localhost:5001
GOTO LOCAL_RUN_DONE

:SKIP_LOCAL_RUN
echo.
echo Local deployment skipped. Image is now live on Docker Hub.

:LOCAL_RUN_DONE
REM --- Local Cleanup ---
echo.
echo Cleaning up dangling images locally...
docker image prune -f

echo.
echo --- Phase 1 Complete: Image Built and Pushed ---
echo Mode: !DEPLOYMENT_LABEL!
echo.
GOTO PHASE_1_DONE

:PHASE_1_SKIP
echo.
echo =====================================================
echo   PHASE 1: SKIPPED
echo =====================================================
echo.
echo Note: Skipping Build and Push phase.
echo Loading Docker credentials from .env for subsequent phases...
echo.

for /f "tokens=2 delims==" %%a in ('findstr /b "DOCKER_USERNAME=" .env 2^>nul') do set "DOCKER_USERNAME=%%a"
for /f "tokens=2 delims==" %%a in ('findstr /b "DOCKER_REPO_NAME=" .env 2^>nul') do set "DOCKER_REPO_NAME=%%a"

if not defined DOCKER_USERNAME set "DOCKER_USERNAME=manrajidevi91"
if not defined DOCKER_REPO_NAME set "DOCKER_REPO_NAME=flask_bot_manager"

if defined DOCKER_USERNAME set "DOCKER_USERNAME=!DOCKER_USERNAME: =!"
if defined DOCKER_REPO_NAME set "DOCKER_REPO_NAME=!DOCKER_REPO_NAME: =!"

echo Using Docker Hub: !DOCKER_USERNAME!/!DOCKER_REPO_NAME!
echo.

:PHASE_1_DONE

REM =====================================================
REM PHASE 2: REMOTE PULL AND DEPLOY (from Docker_pull.bat)
REM =====================================================

IF "!RUN_PHASE_2!"=="1" GOTO PHASE_2_EXECUTE
GOTO PHASE_2_SKIP

:PHASE_2_EXECUTE
echo.
echo =====================================================
echo   PHASE 2: REMOTE PULL AND DEPLOY
echo =====================================================
echo --- Remote Docker Pull ---

set "DEFAULT_VPS_TARGET=kdhakar-dockge@168.231.102.163"
set "DEFAULT_VPS_PATH=~/htdocs/dockge.kdhakar.com/dockge-stacks/flask_bot_manager"

set /p "VPS_TARGET=Enter VPS SSH target (user@host) [%DEFAULT_VPS_TARGET%]: "
if not defined VPS_TARGET set "VPS_TARGET=%DEFAULT_VPS_TARGET%"

set /p "VPS_PATH=Enter remote application path [%DEFAULT_VPS_PATH%]: "
if not defined VPS_PATH set "VPS_PATH=%DEFAULT_VPS_PATH%"

set "DOCKER_IMAGE_USERNAME=!DOCKER_USERNAME!"
set "DOCKER_IMAGE_REPO=!DOCKER_REPO_NAME!"

if not defined DOCKER_IMAGE_USERNAME set "DOCKER_IMAGE_USERNAME=manrajidevi91"
if not defined DOCKER_IMAGE_REPO set "DOCKER_IMAGE_REPO=flask_bot_manager"

echo.
echo Docker Hub username: !DOCKER_IMAGE_USERNAME!
set /p "CUSTOM_USERNAME=Enter custom Docker Hub username (or press Enter to use default): "
if defined CUSTOM_USERNAME (
    set "DOCKER_IMAGE_USERNAME=!CUSTOM_USERNAME!"
    echo Using custom username: !DOCKER_IMAGE_USERNAME!
)

echo.
echo Repository: !DOCKER_IMAGE_REPO!
set /p "CUSTOM_REPO=Enter custom repository name (or press Enter to use default): "
if defined CUSTOM_REPO (
    set "DOCKER_IMAGE_REPO=!CUSTOM_REPO!"
    echo Using custom repository: !DOCKER_IMAGE_REPO!
)

set "DOCKER_IMAGE=!DOCKER_IMAGE_USERNAME!/!DOCKER_IMAGE_REPO!:latest"
echo.
echo Using image: !DOCKER_IMAGE!

set /p "DOCKER_PULL_LOGIN=Does the VPS require docker login before pulling? (Y/N): "
if not defined DOCKER_PULL_LOGIN set "DOCKER_PULL_LOGIN=N"

if /I "!DOCKER_PULL_LOGIN!"=="Y" (
    set "REMOTE_COMMAND=cd %VPS_PATH% && docker login && docker pull !DOCKER_IMAGE! && docker compose down && docker compose up -d"
) ELSE (
    set "REMOTE_COMMAND=cd %VPS_PATH% && docker pull !DOCKER_IMAGE! && docker compose down && docker compose up -d"
)

echo.
echo Executing remote pull on %VPS_TARGET%...
ssh -o BatchMode=no %VPS_TARGET% "!REMOTE_COMMAND!"
IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Remote docker pull failed.
    pause
    exit /b 1
)

echo.
echo --- Phase 2 Complete: Remote Pull and Deploy Successful ---
echo.
GOTO PHASE_2_DONE

:PHASE_2_SKIP
echo.
echo =====================================================
echo   PHASE 2: SKIPPED
echo =====================================================
echo.
echo Skipping Remote Deploy phase.
echo.

:PHASE_2_DONE

REM =====================================================
REM PHASE 3: REMOTE CLEANUP (from Docker_cleanup.bat)
REM =====================================================

IF "!RUN_PHASE_3!"=="1" GOTO PHASE_3_EXECUTE
GOTO PHASE_3_SKIP

:PHASE_3_EXECUTE
echo.
echo =====================================================
echo   PHASE 3: REMOTE DOCKER CLEANUP
echo =====================================================
echo --- Remote Docker Cleanup ---

if defined VPS_TARGET (
    set "CLEANUP_VPS_TARGET=%VPS_TARGET%"
    echo Using VPS target from Phase 2: !CLEANUP_VPS_TARGET!
) else (
    set "DEFAULT_VPS_TARGET=kdhakar-dockge@168.231.102.163"
    set /p "CLEANUP_VPS_TARGET=Enter VPS SSH target user@host [!DEFAULT_VPS_TARGET!]: "
    if not defined CLEANUP_VPS_TARGET set "CLEANUP_VPS_TARGET=!DEFAULT_VPS_TARGET!"
)

set /p "CONFIRM_CLEANUP=Run cleanup on !CLEANUP_VPS_TARGET!? (Y/N): "
if not defined CONFIRM_CLEANUP set "CONFIRM_CLEANUP=Y"

if /I "!CONFIRM_CLEANUP!"=="Y" GOTO DO_CLEANUP
GOTO SKIP_CLEANUP

:DO_CLEANUP
set "REMOTE_COMMAND=docker image prune -f"

echo.
echo Executing cleanup on !CLEANUP_VPS_TARGET!...
ssh -o BatchMode=no !CLEANUP_VPS_TARGET! "!REMOTE_COMMAND!"

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Cleanup failed.
    pause
    exit /b 1
)

echo.
echo --- Phase 3 Complete: Remote Cleanup Successful ---
echo.
GOTO PHASE_3_DONE

:SKIP_CLEANUP
echo.
echo --- Phase 3 Skipped: Cleanup Cancelled by User ---

:PHASE_3_DONE
GOTO SUMMARY

:PHASE_3_SKIP
echo.
echo =====================================================
echo   PHASE 3: SKIPPED
echo =====================================================
echo.
echo Skipping Remote Cleanup phase.
echo.

REM =====================================================
REM SUMMARY
REM =====================================================
:SUMMARY
echo.
echo =====================================================
echo   DEPLOYMENT COMPLETED
echo =====================================================
echo.
echo Mode: !MODE_LABEL!
echo.
echo Summary:
IF "!RUN_PHASE_1!"=="1" echo   - Phase 1: Build and Push - COMPLETED
IF "!RUN_PHASE_1!"=="0" echo   - Phase 1: Build and Push - SKIPPED
IF "!RUN_PHASE_2!"=="1" echo   - Phase 2: Remote Deploy - COMPLETED
IF "!RUN_PHASE_2!"=="0" echo   - Phase 2: Remote Deploy - SKIPPED
IF "!RUN_PHASE_3!"=="1" echo   - Phase 3: Remote Cleanup - COMPLETED
IF "!RUN_PHASE_3!"=="0" echo   - Phase 3: Remote Cleanup - SKIPPED
echo.
pause
