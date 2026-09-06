@echo off
set "MC_DIR=%INST_MC_DIR%"
if "%MC_DIR:~-1%"=="\" set "MC_DIR=%MC_DIR:~0,-1%"

:: Verificar Opt-Out de Telemetria
if exist "%MC_DIR%\.no_telemetry" (
    exit /b 0
)

:: Envoltorio VBS silencioso para Fallback (Post-Exit)
set "VBS_FILE=%TEMP%\run_postexit_%RANDOM%.vbs"
set "PS_SCRIPT=%~dp0enviar-logs.ps1"

echo Set WshShell = CreateObject("WScript.Shell") > "%VBS_FILE%"
echo WshShell.Run "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ ^& "%PS_SCRIPT%" ^& """ -mcDir """ ^& "%MC_DIR%" ^& """ -postexit", 0, False >> "%VBS_FILE%"

cscript //nologo "%VBS_FILE%"
del "%VBS_FILE%" /q
