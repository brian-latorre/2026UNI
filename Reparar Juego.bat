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
echo Sin embargo, se reiniciara la configuracion de teclas.
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

echo Eliminando configuraciones de mods (config)...
if exist "%MC_DIR%\config" rmdir /s /q "%MC_DIR%\config"

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
