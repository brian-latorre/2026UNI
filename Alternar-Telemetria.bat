@echo off
chcp 65001 >nul
title Configuración de Telemetría 2026UNI

set "TARGET_DIR=%APPDATA%\.minecraft\2026UNI_Launcher\PineconeMC\instances\2026UNI\.minecraft"
set "FLAG_FILE=%TARGET_DIR%\.no_telemetry"

echo ========================================================
echo        Gestor de Telemetria de Errores - 2026UNI
echo ========================================================
echo.
echo La telemetria nos ayuda a recibir reportes de crasheos
echo en tiempo real para brindarte soporte rapidamente.
echo La informacion enviada incluye: Tiempos de juego, RAM,
echo espacio en disco y logs de error anonimizados.
echo.

if not exist "%TARGET_DIR%" (
    echo [ERROR] No se pudo encontrar la carpeta de la instancia.
    echo Probablemente aun no has instalado o iniciado el juego por primera vez.
    echo Ruta buscada: %TARGET_DIR%
    echo.
    pause
    exit /b 1
)

if exist "%FLAG_FILE%" (
    echo ESTADO ACTUAL: [DESACTIVADA] (No se envia ningun dato)
    echo.
    echo Escribe 'ACTIVAR' para volver a encenderla o presiona ENTER para salir.
    set /p "opcion=> "
    if /i "%opcion%"=="ACTIVAR" (
        del "%FLAG_FILE%" /q
        echo.
        echo [EXITO] Telemetria ACTIVADA. Gracias por tu apoyo.
    )
) else (
    echo ESTADO ACTUAL: [ACTIVADA] (Ayudando al servidor)
    echo.
    echo Escribe 'DESACTIVAR' para apagarla o presiona ENTER para salir.
    set /p "opcion=> "
    if /i "%opcion%"=="DESACTIVAR" (
        echo. > "%FLAG_FILE%"
        echo.
        echo [EXITO] Telemetria DESACTIVADA. Tu privacidad es importante.
    )
)

echo.
pause
