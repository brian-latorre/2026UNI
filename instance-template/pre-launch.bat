@echo off
chcp 65001 >nul

set "MC_DIR=%INST_MC_DIR%"
if "%MC_DIR:~-1%"=="\" set "MC_DIR=%MC_DIR:~0,-1%"

:: 1. Revisar crasheos pendientes o cola offline de la sesion anterior (Silencioso)
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0enviar-logs.ps1" -mcDir "%MC_DIR%" -startup

:: 2. Actualizar mods con Packwiz
"%INST_JAVA%" -jar "%INST_MC_DIR%\packwiz-installer-bootstrap.jar" -g https://brian-latorre.github.io/2026UNI/pack.toml
