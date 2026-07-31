@echo off
setlocal
echo =======================================================
echo     RESTAURAR VERSION ANTERIOR (NUEVO COMMIT)
echo =======================================================
echo Este script creara un nuevo commit que contiene exactamente
echo el estado del proyecto en el commit especificado, 
echo manteniendo todo el historial intacto.
echo.
set /p COMMIT_HASH="Ingresa el Hash del commit a restaurar (ej. 1a2b3c4): "
if "%COMMIT_HASH%"=="" (
    echo Operacion cancelada.
    pause
    exit /b
)

:: Extraer el commit actual
for /f "tokens=*" %%a in ('git rev-parse HEAD') do set CURRENT_COMMIT=%%a
if "%CURRENT_COMMIT%"=="" (
    echo Error: No se pudo determinar el commit actual.
    pause
    exit /b
)

echo.
echo 1. Limpiando cambios no guardados en local...
git reset --hard HEAD

echo 2. Vaciando directorio actual y extrayendo el commit antiguo...
git rm -r --quiet .
git checkout %COMMIT_HASH% -- .

echo 3. Restaurando archivos protegidos...
git checkout %CURRENT_COMMIT% -- Restaurar-Version.bat
git checkout %CURRENT_COMMIT% -- .github/workflows/publish-pack.yml

echo 4. Preparando el nuevo commit de restauracion...
git add -A

echo 5. Haciendo el commit...
git commit -m "Restaurar a version: %COMMIT_HASH%"

echo 6. Subiendo la restauracion a GitHub...
git push

echo.
echo =======================================================
echo ¡Restauracion completada con exito!
echo El proyecto ha vuelto a la version %COMMIT_HASH%
echo y las Acciones de GitHub deberian estarse ejecutando.
echo =======================================================
pause
