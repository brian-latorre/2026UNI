@echo off
chcp 65001 >nul
color 0B
echo ========================================================
echo        HERRAMIENTA DE REPARACION - 2026UNI
echo ========================================================
echo.
echo Esta herramienta solucionara los problemas de crasheo o
echo cuando el juego se ve raro (ej. sin texturas o bugs).
echo.
echo No perderas tus mundos, capturas de pantalla, ni los
echo resourcepacks que hayas descargado manualmente.
echo Tus teclas y candados estaran seguros gracias a SmartKeySync.
echo.
pause
echo.
echo Buscando instalacion de Minecraft...
set MC_DIR=%APPDATA%\.minecraft\2026UNI_Launcher\PineconeMC\instances\2026UNI\.minecraft

if not exist "%MC_DIR%" (
    color 0C
    echo ERROR: No se encontro la carpeta del juego.
    echo Asegurate de haber instalado el juego primero.
    pause
    exit
)

echo Eliminando opciones corruptas (options.txt)...
if exist "%MC_DIR%\options.txt" del /f /q "%MC_DIR%\options.txt"

echo Preservando configuracion de teclas (SmartKeySync)...
set "SKS_CLIENT=%MC_DIR%\config\smartkeysync\client.json"
set "SKS_BACKUP=%TEMP%\smartkeysync_client_repair.json"
if exist "%SKS_CLIENT%" (
    copy /y "%SKS_CLIENT%" "%SKS_BACKUP%" >nul
)

echo Eliminando configuraciones de mods (config)...
if exist "%MC_DIR%\config" rmdir /s /q "%MC_DIR%\config"

if exist "%SKS_BACKUP%" (
    if not exist "%MC_DIR%\config\smartkeysync" mkdir "%MC_DIR%\config\smartkeysync"
    copy /y "%SKS_BACKUP%" "%SKS_CLIENT%" >nul
    del /f /q "%SKS_BACKUP%" >nul
    echo Teclas de SmartKeySync restauradas con exito.
)

echo Eliminando mods (para evitar infiltrados y conflictos)...
if exist "%MC_DIR%\mods" rmdir /s /q "%MC_DIR%\mods"

echo Eliminando cache de memoria e indice...
if exist "%MC_DIR%\.mixin.out" rmdir /s /q "%MC_DIR%\.mixin.out"
if exist "%MC_DIR%\packwiz.json" del /f /q "%MC_DIR%\packwiz.json"

color 0A
echo.
echo ========================================================
echo REPARACION COMPLETADA CON EXITO!
echo ========================================================
echo.
echo Por favor, abre el juego desde el Launcher nuevamente.
echo La primera vez tardara un poco mas en descargar las
echo configuraciones limpias del servidor.
echo.
pause
