@echo off
setlocal enabledelayedexpansion
title Imara Finance - Launcher
cd /d "%~dp0"

:menu
cls
echo ================================================
echo   IMARA FINANCE - Launcher
echo ================================================
echo.
echo   1. Run locally  (Node.js + local PostgreSQL)
echo   2. Run with Docker  (docker compose)
echo   3. Stop Docker containers
echo   4. View Docker logs
echo   5. Exit
echo.
set "choice="
set /p choice="Select an option [1-5]: "

if "%choice%"=="1" goto local
if "%choice%"=="2" goto docker
if "%choice%"=="3" goto dockerdown
if "%choice%"=="4" goto dockerlogs
if "%choice%"=="5" goto end
echo Invalid option.
pause
goto menu

:ensure_env
if not exist ".env" (
    if exist ".env.example" (
        echo No .env file found - creating one from .env.example with local defaults.
        copy /y ".env.example" ".env" >nul
    ) else (
        echo WARNING: .env.example not found. You will need to create .env manually.
    )
)
exit /b 0

:local
echo.
where node >nul 2>nul
if errorlevel 1 (
    echo Node.js was not found on PATH. Install it from https://nodejs.org/ and try again.
    pause
    goto menu
)

call :ensure_env

if not exist "node_modules" (
    echo Installing dependencies, this may take a minute...
    call npm install
    if errorlevel 1 (
        echo npm install failed. See the output above.
        pause
        goto menu
    )
)

echo.
echo This mode needs a PostgreSQL server already running and reachable using
echo the SQL_HOST / SQL_DB_NAME / SQL_ADMIN_USER / SQL_ADMIN_PASSWORD values
echo in your .env file. Edit .env now if you haven't already.
echo.
set "pushdb="
set /p pushdb="Create/update database tables now with 'npm run db:push'? [Y/n]: "
if /i not "%pushdb%"=="n" (
    call npm run db:push
)

echo.
echo Starting the dev server at http://localhost:3000 (Ctrl+C to stop)...
echo.
call npm run dev
goto menu

:docker
echo.
where docker >nul 2>nul
if errorlevel 1 (
    echo Docker was not found on PATH. Install Docker Desktop from
    echo https://www.docker.com/products/docker-desktop/ and try again.
    pause
    goto menu
)

call :ensure_env

rem Read HOST_APP_PORT from .env (defaults to 3000) so the URL below is
rem right even if the port was changed to avoid a collision.
set "APP_PORT=3000"
if exist ".env" (
    for /f "usebackq tokens=1,2 delims==" %%A in (".env") do (
        if /i "%%A"=="HOST_APP_PORT" if not "%%B"=="" set "APP_PORT=%%B"
    )
)

echo Building and starting containers (app + PostgreSQL)...
docker compose up -d --build
if errorlevel 1 (
    echo docker compose failed to start. See the output above.
    pause
    goto menu
)

echo.
echo Waiting for the database to become healthy...
rem "timeout" errors out without a real console attached in some contexts;
rem ping is a plain time-based delay that doesn't depend on one.
ping -n 7 127.0.0.1 >nul

echo Applying database schema (safe to re-run; only touches missing tables/columns)...
rem -T disables pseudo-TTY allocation so this can't hang waiting on a
rem terminal that isn't there.
docker compose exec -T app npm run db:push

echo.
echo ================================================
echo   App running at http://localhost:!APP_PORT!
echo   Demo login: any seeded account, password Imara@2025
echo ================================================
echo.
start "" "http://localhost:!APP_PORT!"
pause
goto menu

:dockerdown
echo.
docker compose down
echo.
echo Containers stopped. The database volume was kept (use
echo "docker compose down -v" manually to also wipe it).
pause
goto menu

:dockerlogs
echo.
echo Press Ctrl+C to stop tailing logs.
docker compose logs app -f
pause
goto menu

:end
endlocal
exit /b 0
