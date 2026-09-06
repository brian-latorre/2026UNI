<#
.SYNOPSIS
    Descarga e instala packwiz para gestionar el modpack.
.DESCRIPTION
    Descarga el binario de packwiz desde GitHub Releases y lo coloca
    en la carpeta del proyecto para uso local.
.NOTES
    Requisito: PowerShell 5.1+ y acceso a internet.
    Alternativa: si tienes Go instalado, puedes correr:
        go install github.com/packwiz/packwiz@latest
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "$PSScriptRoot\..\tools"
)

$ErrorActionPreference = "Stop"

# --- Configuración ---
$PackwizRepo = "packwiz/packwiz"
$PackwizBinary = "packwiz.exe"
$InstallPath = Join-Path (Resolve-Path $InstallDir -ErrorAction SilentlyContinue ?? $InstallDir) $PackwizBinary

# --- Verificar si ya está instalado ---
$existingPackwiz = Get-Command packwiz -ErrorAction SilentlyContinue
if ($existingPackwiz) {
    Write-Host "[OK] packwiz ya está disponible en: $($existingPackwiz.Source)" -ForegroundColor Green
    & packwiz --version 2>$null
    Write-Host ""
    Write-Host "Si quieres reinstalar, elimina el binario actual y vuelve a correr este script." -ForegroundColor Yellow
    exit 0
}

# --- Verificar alternativa con Go ---
$goInstalled = Get-Command go -ErrorAction SilentlyContinue
if ($goInstalled) {
    Write-Host "[INFO] Go está instalado. Instalando packwiz via 'go install'..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        & go install github.com/packwiz/packwiz@latest
        
        # Verificar que se instaló
        $gobin = & go env GOPATH
        $gobin = Join-Path $gobin "bin\packwiz.exe"
        
        if (Test-Path $gobin) {
            Write-Host "[OK] packwiz instalado en: $gobin" -ForegroundColor Green
            Write-Host ""
            Write-Host "Asegúrate de que $(Split-Path $gobin) esté en tu PATH." -ForegroundColor Yellow
            Write-Host "Puedes verificar con: packwiz --version" -ForegroundColor Yellow
        }
        exit 0
    }
    catch {
        Write-Host "[WARN] Error instalando via Go. Intentando descarga directa..." -ForegroundColor Yellow
    }
}

# --- Descarga directa desde GitHub Releases ---
Write-Host "[INFO] Descargando packwiz desde GitHub..." -ForegroundColor Cyan

# Obtener la última release
$releaseUrl = "https://api.github.com/repos/$PackwizRepo/releases/latest"
try {
    $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{ "User-Agent" = "2026UNI-Setup" }
}
catch {
    Write-Host "[ERROR] No se pudo acceder a la API de GitHub." -ForegroundColor Red
    Write-Host "Alternativas manuales:" -ForegroundColor Yellow
    Write-Host "  1. Descarga packwiz desde: https://github.com/$PackwizRepo/releases" -ForegroundColor Yellow
    Write-Host "  2. Instala Go y corre: go install github.com/packwiz/packwiz@latest" -ForegroundColor Yellow
    exit 1
}

# Buscar el asset de Windows x64
$asset = $release.assets | Where-Object { $_.name -like "*windows*amd64*" -or $_.name -like "*windows*x86_64*" -or $_.name -eq "packwiz.exe" } | Select-Object -First 1

if (-not $asset) {
    # Si no hay binario precompilado para Windows, intentar con el binario genérico
    $asset = $release.assets | Where-Object { $_.name -like "packwiz*" -and $_.name -notlike "*linux*" -and $_.name -notlike "*darwin*" -and $_.name -notlike "*mac*" } | Select-Object -First 1
}

if (-not $asset) {
    Write-Host "[ERROR] No se encontró un binario de packwiz para Windows en la release $($release.tag_name)." -ForegroundColor Red
    Write-Host "Descarga manual: https://github.com/$PackwizRepo/releases/tag/$($release.tag_name)" -ForegroundColor Yellow
    Write-Host "O instala Go y corre: go install github.com/packwiz/packwiz@latest" -ForegroundColor Yellow
    exit 1
}

# Crear directorio de instalación si no existe
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# Descargar
$downloadUrl = $asset.browser_download_url
$tempFile = Join-Path $env:TEMP "packwiz_download_$($asset.name)"

Write-Host "  Versión: $($release.tag_name)" -ForegroundColor Gray
Write-Host "  Archivo: $($asset.name)" -ForegroundColor Gray
Write-Host "  Descargando..." -ForegroundColor Gray

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
}
catch {
    Write-Host "[ERROR] Error descargando: $_" -ForegroundColor Red
    exit 1
}

# Si es un .zip o .tar.gz, extraer
if ($asset.name -like "*.zip") {
    Expand-Archive -Path $tempFile -DestinationPath $InstallDir -Force
    Remove-Item $tempFile -Force
}
elseif ($asset.name -like "*.exe") {
    Copy-Item $tempFile $InstallPath -Force
    Remove-Item $tempFile -Force
}
else {
    # Asumir que es el binario directo
    Copy-Item $tempFile $InstallPath -Force
    Remove-Item $tempFile -Force
}

# Verificar
$finalPath = Get-ChildItem $InstallDir -Filter "packwiz*" -Recurse | Select-Object -First 1
if ($finalPath) {
    Write-Host ""
    Write-Host "[OK] packwiz instalado en: $($finalPath.FullName)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Para usarlo, agrega esta carpeta a tu PATH:" -ForegroundColor Yellow
    Write-Host "  $InstallDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "O usa la ruta completa: $($finalPath.FullName)" -ForegroundColor Yellow
}
else {
    Write-Host "[ERROR] No se encontró el binario después de la extracción." -ForegroundColor Red
    exit 1
}
