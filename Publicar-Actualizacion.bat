@echo off
chcp 65001 >nul
title 2026UNI - Publicar Actualizacion (Normal + Lite)

powershell.exe -ExecutionPolicy Bypass -File ".\scripts\publish.ps1" -Perfil All

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