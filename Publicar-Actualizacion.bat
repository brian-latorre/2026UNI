@echo off
chcp 65001 >nul
title 2026UNI - Publicar Actualizacion

set /p mensaje="Escribe un mensaje corto de lo que cambiaste (ej: Nuevas imagenes de fancymenu) [Actualizacion del modpack]: "
if "%mensaje%"=="" set mensaje=Actualizacion del modpack

powershell.exe -ExecutionPolicy Bypass -File ".\scripts\publish.ps1" -CommitMessage "%mensaje%"

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
