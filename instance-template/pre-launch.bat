@echo off
chcp 65001 >nul

:: 1. Revisar crasheos pendientes de la sesión anterior (Doble Seguridad)
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0enviar-logs.ps1" -mcDir "%INST_MC_DIR%" -startup

:: 2. Actualizar mods con Packwiz
"%INST_JAVA%" -jar "%INST_MC_DIR%\packwiz-installer-bootstrap.jar" https://brian-latorre.github.io/2026UNI/pack.toml
