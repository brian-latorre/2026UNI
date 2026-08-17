@echo off
set "MC_DIR=%INST_MC_DIR%"
if "%MC_DIR:~-1%"=="\" set "MC_DIR=%MC_DIR:~0,-1%"

start /b powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0enviar-logs.ps1" -mcDir "%MC_DIR%"
