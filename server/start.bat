@echo off
chcp 65001 >nul
title Little Alien Race Server
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is not installed. Download it from https://nodejs.org then run this file again.
  pause
  exit /b 1
)

if not exist node_modules (
  echo Installing server files, one time only...
  call npm install --omit=dev
)

set TSIP=
for /f %%i in ('tailscale ip -4 2^>nul') do set TSIP=%%i

echo.
echo ================================================
echo   Little Alien race server
echo ================================================
if defined TSIP (
  echo   Friends type this in the game ^(RACE ^> SERVER^):
  echo   %TSIP%:8787
) else (
  echo   Tailscale not found. Install it, sign in, then run this again.
)
echo.
echo   Close this window to stop the server.
echo ================================================
echo.

node server.js
pause
