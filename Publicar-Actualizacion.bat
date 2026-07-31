@echo off
chcp 65001 >nul
title 2026UNI - Publicar Actualizacion

set /p version="1. Ingrese la versión de la actualización (ej: 1.0.2) [Enter para auto-incrementar]: "
set /p mensaje="2. Escribe un comentario corto de lo que cambiaste (ej: Nuevas imágenes): "
if "%mensaje%"=="" set mensaje=Actualización del modpack

powershell.exe -ExecutionPolicy Bypass -File ".\scripts\publish.ps1" -CommitMessage "%mensaje%" -Version "%version%"

if %errorlevel% neq 0 (
    echo.
    echo =======================================================
    echo   ERROR DURANTE LA ACTUALIZACION
    echo =======================================================
    echo Revisa el error rojo de arriba para ver que fallo.
    echo.
    pause
    exit /b %errorlevel%
)

pause
exit /b 0
