@echo off
color 0B
title 2026UNI - Publicar Actualizacion

echo =======================================================
echo   1-CLICK UPDATE: 2026UNI MODPACK
echo =======================================================
echo.
echo Este script va a:
echo  1. Sincronizar tus configuraciones de Minecraft.
echo  2. Refrescar el index de packwiz.
echo  3. Subir los cambios a GitHub para que tus amigos los reciban.
echo.
pause

echo.
echo [PASO 1] Sincronizando overrides (fancymenu, configs, shaders, etc.)...
powershell.exe -ExecutionPolicy Bypass -File ".\scripts\sync-overrides.ps1"
if %errorlevel% neq 0 goto :error

echo.
echo [PASO 2] Construyendo y validando el pack...
powershell.exe -ExecutionPolicy Bypass -File ".\scripts\build-pack.ps1"
if %errorlevel% neq 0 goto :error

echo.
echo [PASO 3] Preparando la subida a GitHub...
set /p mensaje="Escribe un mensaje corto de lo que cambiaste (ej: Nuevas imagenes de fancymenu): "
if "%mensaje%"=="" set mensaje="Actualizacion del modpack"

echo.
echo Subiendo cambios a la nube...
git add .
git commit -m "%mensaje%"
git push -u origin main
if %errorlevel% neq 0 goto :error

echo.
color 0A
echo =======================================================
echo   EXITO! ACTUALIZACION PUBLICADA
echo =======================================================
echo Tus amigos recibiran estos cambios automaticamente la
echo proxima vez que abran el juego.
echo.
pause
exit

:error
echo.
color 0C
echo =======================================================
echo   ERROR DURANTE LA ACTUALIZACION
echo =======================================================
echo Algo fallo en los pasos anteriores. Revisa el texto de
echo arriba para ver que paso.
echo.
pause
exit
