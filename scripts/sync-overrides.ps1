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

# Cargar Helpers
$helpersPath = Join-Path $PSScriptRoot "console-helpers.ps1"
if (Test-Path $helpersPath) { . $helpersPath }

# === Validaciones ===
if (-not (Test-Path $SourceInstance)) {
    Write-ErrorMsg "No se encontró la instancia en: $SourceInstance"
    Write-Warn "Usa -SourceInstance para especificar la ruta correcta."
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

Write-Info "Origen:  $SourceInstance"
Write-Info "Destino: $PackDir"
if ($DryRun) { Write-Warn "MODO: DRY RUN (no se copia nada)" }
Write-Host ""
Write-Info "Explicacion: Este script copia las carpetas de configuracion (como 'config', 'resourcepacks',"
Write-Info "'shaderpacks', etc.) desde tu instalacion real de Minecraft hacia la carpeta 'pack'."
Write-Info "Esto asegura que al actualizar, los jugadores reciban los mismos menus y ajustes que tu."
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
    "patchouli_data.json"
)

# === Carpetas a EXCLUIR siempre (dentro de las carpetas sincronizadas) ===
$ExcludeDirs = @(
    ".git",
    ".cache",
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
    "desktop.ini",
    "smartkeysync-client.json"
)

# === Proceso de sincronización ===
$totalItems = 0
$skippedItems = 0

# --- Sincronizar carpetas ---
foreach ($folder in $SyncFolders) {
    $sourcePath = Join-Path $SourceInstance $folder
    $destPath = Join-Path $PackDir $folder
    
    if (-not (Test-Path $sourcePath)) {
        Write-Info "[SKIP] $folder/ - no existe en la instancia"
        $skippedItems++
        continue
    }
    
    $itemCount = (Get-ChildItem $sourcePath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    
    if ($DryRun) {
        Write-Warn "[DRY]  $folder/ - $itemCount archivos"
    }
    else {
        $robocopyArgs = @(
            $sourcePath,
            $destPath,
            "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NC", "/NS", "/NP",
            "/XD"
        ) + $ExcludeDirs + "/XF" + $ExcludeFiles
        
        Write-Info "Copiando $folder/ ($itemCount archivos)..."
        # Eliminar destino si existe para hacer copia limpia
        if (Test-Path $destPath) {
            Remove-Item $destPath -Recurse -Force
        }
        
        & robocopy @robocopyArgs | Out-Null
        if ($LASTEXITCODE -lt 8) {
            Write-Success "Copiado $folder/"
        } else {
            Write-ErrorMsg "Error al copiar $folder/ (Codigo $LASTEXITCODE)"
        }
    }
    
    $totalItems++
}

# --- Sincronizar archivos individuales ---
foreach ($file in $SyncFiles) {
    $sourcePath = Join-Path $SourceInstance $file
    $destPath = Join-Path $PackDir $file
    
    if (-not (Test-Path $sourcePath)) {
        Write-Info "[SKIP] $file - no existe en la instancia"
        $skippedItems++
        continue
    }
    
    if ($DryRun) {
        Write-Warn "[DRY]  $file"
    }
    else {
        Copy-Item $sourcePath $destPath -Force
        Write-Success "Copiado $file"
    }
    
    $totalItems++
}

# === Reporte ===
Write-Host ""
Write-Success "Sincronizados: $totalItems"
Write-Info "Saltados:      $skippedItems"

# === Advertencias ===
# Verificar carpetas opcionales que podrían existir
$optionalFolders = @("iammusicplayerrenewed", "visual_keybinder")
foreach ($folder in $optionalFolders) {
    $sourcePath = Join-Path $SourceInstance $folder
    if (Test-Path $sourcePath) {
        Write-Warn "Carpeta opcional encontrada: $folder/. Agregala al array `$SyncFolders si la necesitas."
    }
}
