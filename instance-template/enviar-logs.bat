@echo off
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0enviar-logs.ps1" -mcDir "%INST_MC_DIR%"
