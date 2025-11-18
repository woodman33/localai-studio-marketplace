@echo off
REM Local AI Studio - One-Click Installer for Windows
REM Usage: Double-click this file or run: INSTALL-WINDOWS.bat

echo =============================================
echo   LOCAL AI STUDIO - INSTALLATION
echo =============================================
echo.
echo Installing your private AI playground...
echo.

REM Check if Docker is installed
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not installed
    echo.
    echo Please install Docker Desktop for Windows:
    echo https://docs.docker.com/desktop/install/windows-install/
    echo.
    pause
    exit /b 1
)

echo [OK] Docker found
echo.

REM Check if Docker Compose is available
docker compose version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker Compose is not available
    echo.
    echo Please ensure Docker Desktop is running
    echo.
    pause
    exit /b 1
)

echo [OK] Docker Compose found
echo.

REM Create data directories
echo Creating data directories...
if not exist "data\backend" mkdir data\backend
if not exist "data\ollama" mkdir data\ollama
echo [OK] Data directories created
echo.

REM Start containers
echo Starting Local AI Studio...
echo This may take 1-2 minutes on first run...
echo.

docker compose up -d

echo.
echo [OK] Containers started
echo.

REM Wait for services
echo Waiting for services to start...
timeout /t 10 /nobreak >nul
echo.

REM Check container status
echo Container Status:
docker compose ps
echo.

echo =============================================
echo   INSTALLATION COMPLETE!
echo =============================================
echo.
echo Access your AI Studio at:
echo    http://localhost:3000
echo.
echo What's included:
echo    - TinyLlama 1.1B (pre-installed and ready)
echo    - 10 additional models available
echo    - One-click model installation
echo    - ChatGPT-like interface
echo    - 100%% private and local
echo.
echo Useful commands:
echo    docker compose ps          - Check status
echo    docker compose logs -f     - View logs
echo    docker compose stop        - Stop services
echo    docker compose restart     - Restart services
echo.
echo Open http://localhost:3000 in your browser to get started!
echo.
pause
