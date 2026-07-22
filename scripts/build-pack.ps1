<#
.SYNOPSIS
    Valida y refresca el pack de packwiz.
.DESCRIPTION
    Ejecuta 'packwiz refresh' en el directorio pack/ para regenerar index.toml,
    luego valida que el pack sea consistente.
.NOTES
    Requiere packwiz instalado (correr scripts/setup-packwiz.ps1 primero).
#>

[CmdletBinding()]
param(
    [string]$PackDir = ".\pack",
    [switch]$Serve  # Si se pasa, inicia un servidor local para probar
)

$ErrorActionPreference = "Stop"

# === Buscar packwiz ===
$packwiz = Get-Command packwiz -ErrorAction SilentlyContinue
if (-not $packwiz) {
    # Buscar en tools/
    $localPackwiz = Join-Path $PWD "tools\packwiz.exe"
    if (Test-Path $localPackwiz) {
        $packwiz = @{ Source = $localPackwiz }
    }
    else {
        Write-Host "[ERROR] packwiz no está instalado." -ForegroundColor Red
        Write-Host "Corre primero: .\scripts\setup-packwiz.ps1" -ForegroundColor Yellow
        exit 1
    }
}

$packwizPath = if ($packwiz.Source) { $packwiz.Source } else { $packwiz.Path }
Write-Host "[INFO] Usando packwiz: $packwizPath" -ForegroundColor Cyan

# === Validar directorio del pack ===
$PackDir = (Resolve-Path (Join-Path $PWD $PackDir) -ErrorAction SilentlyContinue).Path
if (-not $PackDir -or -not (Test-Path (Join-Path $PackDir "pack.toml"))) {
    Write-Host "[ERROR] No se encontró pack.toml en: $PackDir" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Build del pack — 2026UNI" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Directorio: $PackDir" -ForegroundColor Gray
Write-Host ""

# === Refresh ===
Write-Host "[1/3] Refrescando index.toml..." -ForegroundColor Green
Push-Location $PackDir
try {
    & $packwizPath refresh
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] packwiz refresh falló con código $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
    Write-Host "  OK" -ForegroundColor Green
}
finally {
    Pop-Location
}

# === Verificar ===
Write-Host ""
Write-Host "[2/3] Verificando consistencia..." -ForegroundColor Green

# Contar archivos .pw.toml (mods registrados)
$modCount = (Get-ChildItem (Join-Path $PackDir "mods") -Filter "*.pw.toml" -ErrorAction SilentlyContinue | Measure-Object).Count

# Contar archivos en overrides (configs, etc.)
$overrideCount = 0
$overrideFolders = @("config", "defaultconfigs", "resourcepacks", "shaderpacks", "showdown", 
                      "emojiful", "emotes", "moonlight-global-datapacks", "fancymenu_data",
                      "otyacraftengine", "patchouli_books", "trees", "server-resource-packs")
foreach ($folder in $overrideFolders) {
    $folderPath = Join-Path $PackDir $folder
    if (Test-Path $folderPath) {
        $overrideCount += (Get-ChildItem $folderPath -Recurse -File | Measure-Object).Count
    }
}

# Archivos sueltos
$looseFiles = @("options.txt", "patchouli_data.json")
foreach ($file in $looseFiles) {
    if (Test-Path (Join-Path $PackDir $file)) {
        $overrideCount++
    }
}

Write-Host "  Mods registrados (.pw.toml):  $modCount" -ForegroundColor White
Write-Host "  Archivos override (configs):  $overrideCount" -ForegroundColor White

# === Validar pack.toml ===
Write-Host ""
Write-Host "[3/3] Validando pack.toml..." -ForegroundColor Green
$packToml = Get-Content (Join-Path $PackDir "pack.toml") -Raw
if ($packToml -match 'minecraft\s*=\s*"1\.20\.1"' -and $packToml -match 'forge\s*=\s*"47\.4\.\d+"') {
    Write-Host "  Minecraft: 1.20.1 ✓" -ForegroundColor Green
    Write-Host "  Forge: detectado ✓" -ForegroundColor Green
}
else {
    Write-Host "  [WARN] Versiones de Minecraft/Forge no coinciden con lo esperado" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Build completo" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# === Servir localmente (opcional) ===
if ($Serve) {
    Write-Host "[INFO] Iniciando servidor local de packwiz..." -ForegroundColor Cyan
    Write-Host "  URL: http://localhost:8080/pack.toml" -ForegroundColor Yellow
    Write-Host "  Presiona Ctrl+C para detener" -ForegroundColor Yellow
    Write-Host ""
    Push-Location $PackDir
    try {
        & $packwizPath serve
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "Tip: Para probar localmente, corre:" -ForegroundColor DarkGray
    Write-Host "  .\scripts\build-pack.ps1 -Serve" -ForegroundColor DarkGray
    Write-Host ""
}
