@echo off
echo.
echo ========================================
echo   Claude Response Router
echo ========================================
echo.
echo Starting response listener...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Start_Router.ps1"
pause
