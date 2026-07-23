<#
.SYNOPSIS
    Sincroniza las carpetas del pack desde tu instancia real de Minecraft a pack/.
.DESCRIPTION
    Copia las carpetas y archivos que deben sincronizarse (config, resourcepacks,
    shaderpacks, options.txt, etc.) desde tu instancia 2026UNI real al directorio
    pack/ del proyecto para que packwiz las distribuya.

    NO copia: logs, saves, screenshots, waypoints, datos de caché, ni datos personales.
.NOTES
    Ejecutar desde la raíz del proyecto o desde scripts/.
    Después de sincronizar, corre: packwiz refresh (desde pack/)
#>

[CmdletBinding()]
param(
    # Ruta a la instancia real de Minecraft (auto-detecta si no se especifica)
    [string]$SourceInstance = "$env:APPDATA\.minecraft\2026UNI",
    
    # Ruta al directorio pack/ del proyecto
    [string]$PackDir = "$PSScriptRoot\..\pack",
    
    # Si está activo, muestra qué haría sin copiar nada
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# === Validaciones ===
if (-not (Test-Path $SourceInstance)) {
    Write-Host "[ERROR] No se encontró la instancia en: $SourceInstance" -ForegroundColor Red
    Write-Host "Usa -SourceInstance para especificar la ruta correcta." -ForegroundColor Yellow
    exit 1
}

$PackDir = Resolve-Path $PackDir -ErrorAction SilentlyContinue
if (-not $PackDir) {
    $PackDir = "$PSScriptRoot\..\pack"
    if (-not (Test-Path $PackDir)) {
        New-Item -ItemType Directory -Path $PackDir -Force | Out-Null
    }
    $PackDir = Resolve-Path $PackDir
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Sincronización de overrides — 2026UNI" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Origen:  $SourceInstance" -ForegroundColor Gray
Write-Host "Destino: $PackDir" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "MODO:    DRY RUN (no se copia nada)" -ForegroundColor Yellow
}
Write-Host ""

# === Carpetas a sincronizar ===
# Estas carpetas se copian COMPLETAS desde la instancia al pack
$SyncFolders = @(
    "config",
    "defaultconfigs",
    "moonlight-global-datapacks",
    "patchouli_books",
    "showdown",
    "emojiful",
    "emotes",
    "otyacraftengine",
    "fancymenu_data",
    "trees",
    "server-resource-packs",
    "resourcepacks",
    "shaderpacks"
)

# === Archivos individuales a sincronizar ===
$SyncFiles = @(
    "options.txt",
    "patchouli_data.json"
)

# === Carpetas a EXCLUIR siempre (dentro de las carpetas sincronizadas) ===
$ExcludeDirs = @(
    ".git",
    ".cache",
    "cache",
    "*cache*",
    "url_texture_cache",
    "__pycache__"
)

# === Archivos a EXCLUIR siempre ===
$ExcludeFiles = @(
    "username_cache.json",
    "*.log",
    "*.tmp",
    ".DS_Store",
    "Thumbs.db",
    "desktop.ini"
)

# === Proceso de sincronización ===
$totalItems = 0
$skippedItems = 0

# --- Sincronizar carpetas ---
foreach ($folder in $SyncFolders) {
    $sourcePath = Join-Path $SourceInstance $folder
    $destPath = Join-Path $PackDir $folder
    
    if (-not (Test-Path $sourcePath)) {
        Write-Host "  [SKIP] $folder/ — no existe en la instancia" -ForegroundColor DarkGray
        $skippedItems++
        continue
    }
    
    $itemCount = (Get-ChildItem $sourcePath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    
    if ($DryRun) {
        Write-Host "  [DRY]  $folder/ — $itemCount archivos" -ForegroundColor Yellow
    }
    else {
        Write-Host "  [SYNC] $folder/ — $itemCount archivos..." -ForegroundColor Green -NoNewline
        
        # Eliminar destino si existe para hacer copia limpia
        if (Test-Path $destPath) {
            Remove-Item $destPath -Recurse -Force
        }
        
        # Copiar con exclusiones
        # Usamos robocopy para copia eficiente con exclusiones
        $robocopyArgs = @(
            $sourcePath,
            $destPath,
            "/E",           # Incluir subdirectorios vacíos
            "/NFL",         # No listar archivos
            "/NDL",         # No listar directorios
            "/NJH",         # No job header
            "/NJS",         # No job summary
            "/NC",          # No class
            "/NS",          # No size
            "/NP"           # No progress
        )
        
        # Agregar exclusiones
        $robocopyArgs += "/XD"
        $robocopyArgs += $ExcludeDirs
        $robocopyArgs += "/XF"
        $robocopyArgs += $ExcludeFiles
        
        & robocopy @robocopyArgs | Out-Null
        
        Write-Host " OK" -ForegroundColor Green
    }
    
    $totalItems++
}

# --- Sincronizar archivos individuales ---
foreach ($file in $SyncFiles) {
    $sourcePath = Join-Path $SourceInstance $file
    $destPath = Join-Path $PackDir $file
    
    if (-not (Test-Path $sourcePath)) {
        Write-Host "  [SKIP] $file — no existe en la instancia" -ForegroundColor DarkGray
        $skippedItems++
        continue
    }
    
    if ($DryRun) {
        Write-Host "  [DRY]  $file" -ForegroundColor Yellow
    }
    else {
        Write-Host "  [SYNC] $file..." -ForegroundColor Green -NoNewline
        Copy-Item $sourcePath $destPath -Force
        Write-Host " OK" -ForegroundColor Green
    }
    
    $totalItems++
}

# === Reporte ===
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Resumen" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Sincronizados: $totalItems" -ForegroundColor Green
Write-Host "  Saltados:      $skippedItems" -ForegroundColor DarkGray
Write-Host ""

if (-not $DryRun) {
    Write-Host "[SIGUIENTE PASO] Ahora corre 'packwiz refresh' desde la carpeta pack/:" -ForegroundColor Yellow
    Write-Host "  cd $PackDir" -ForegroundColor Yellow
    Write-Host "  packwiz refresh" -ForegroundColor Yellow
    Write-Host ""
}

# === Advertencias ===
# Verificar carpetas opcionales que podrían existir
$optionalFolders = @("iammusicplayerrenewed", "visual_keybinder")
foreach ($folder in $optionalFolders) {
    $sourcePath = Join-Path $SourceInstance $folder
    if (Test-Path $sourcePath) {
        Write-Host "[INFO] Carpeta opcional encontrada: $folder/" -ForegroundColor DarkYellow
        Write-Host "       Si quieres incluirla, agregala al array `$SyncFolders en este script." -ForegroundColor DarkYellow
    }
}
