@echo off
rem Quick build entry point for Windows.
rem
rem The project's toolchains run in Docker, driven from WSL (see README.md), so
rem this forwards to build.sh inside your default WSL distro.
rem
rem   build.bat                    Windows scene client, release
rem   build.bat win-client debug   Windows scene client, debug
rem   build.bat win                all Windows clients
rem   build.bat servers            Linux servers (built in Docker via WSL)
rem   build.bat --help             all targets and options
setlocal

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

where wsl >nul 2>&1
if errorlevel 1 (
    echo error: WSL was not found. Install it with "wsl --install -d Ubuntu", then see README.md.
    exit /b 1
)

if "%~1"=="" (
    wsl --cd "%ROOT%" bash ./build.sh win-client
) else (
    wsl --cd "%ROOT%" bash ./build.sh %*
)
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo Build failed with exit code %RC%.
    exit /b %RC%
)
exit /b 0
