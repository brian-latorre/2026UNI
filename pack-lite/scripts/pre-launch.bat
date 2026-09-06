@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "MC_DIR=%INST_MC_DIR%"
if "%MC_DIR:~-1%"=="\" set "MC_DIR=%MC_DIR:~0,-1%"

:: 1. Determinar perfil activo (Normal o Lite) y apuntar a su pack de Packwiz
set "PACKWIZ_URL=https://brian-latorre.github.io/2026UNI/pack/pack.toml"
if exist "%MC_DIR%\perfil.txt" (
    set /p PERFIL_ACTIVO=<"%MC_DIR%\perfil.txt"
    if /i "!PERFIL_ACTIVO!"=="Lite" (
        set "PACKWIZ_URL=https://brian-latorre.github.io/2026UNI/pack-lite/pack.toml"
    )
)

:: 2. Actualizar mods con Packwiz segun el perfil activo
"%INST_JAVA%" -jar "%INST_MC_DIR%\packwiz-installer-bootstrap.jar" -g !PACKWIZ_URL!

:: 3. Verificar Opt-Out de Telemetria
if exist "%MC_DIR%\.no_telemetry" (
    echo [Telemetria] Desactivada por el usuario. Saltando monitoreo.
    exit /b 0
)

:: 3. Generar envoltorio VBS para ejecución 100% invisible
set "VBS_FILE=%TEMP%\run_watchdog_%RANDOM%.vbs"
set "PS_SCRIPT=%~dp0enviar-logs.ps1"

echo Set WshShell = CreateObject("WScript.Shell") > "%VBS_FILE%"
:: Primero, ejecutamos en modo -startup para procesar crasheos por apagón de la sesión anterior
echo WshShell.Run "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ ^& "%PS_SCRIPT%" ^& """ -mcDir """ ^& "%MC_DIR%" ^& """ -startup", 0, False >> "%VBS_FILE%"
:: Segundo, lanzamos el watchdog para monitorear la sesión que está a punto de iniciar
echo WshShell.Run "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ ^& "%PS_SCRIPT%" ^& """ -mcDir """ ^& "%MC_DIR%" ^& """ -watchdog", 0, False >> "%VBS_FILE%"

:: Ejecutar el envoltorio silencioso
cscript //nologo "%VBS_FILE%"

:: Limpiar VBS temporal
del "%VBS_FILE%" /q
