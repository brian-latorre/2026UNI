@echo off
:: Ejecuta el script de PowerShell en modo oculto para que solo se vea la GUI
start /min powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0scripts\GUI-Configurador.ps1"
exit
