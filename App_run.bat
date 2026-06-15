@echo off
setlocal enabledelayedexpansion

REM Get project directory
set "PROJECT_DIR=%~dp0"
set "PORT=5000"
echo Project directory: %PROJECT_DIR%
echo Local Port: %PORT%

REM Deactivate any active conda environment (optional but safe)
call conda deactivate >nul 2>&1

REM Activate virtual environment (required for Python scripts)
call "%PROJECT_DIR%venv\Scripts\activate.bat" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Virtual environment not found. Please run setup.bat first.
    pause
    exit /b 1
)

REM Run the main Python application script
"%PROJECT_DIR%venv\Scripts\python.exe" "%PROJECT_DIR%run.py"

set EXIT_CODE=%ERRORLEVEL%
echo.
if %EXIT_CODE% equ 0 (
    echo [INFO] Application exited normally.
) else (
    echo [ERROR] Application exited with code %EXIT_CODE%.
    echo Check watcher_crash.log for details if it was a watcher failure.
)

pause
