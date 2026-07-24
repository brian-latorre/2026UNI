<#
.SYNOPSIS
    Valida y refresca el pack de packwiz.
#>

[CmdletBinding()]
param(
    [string]$PackDir = ".\pack",
    [switch]$Serve
)

$ErrorActionPreference = "Stop"

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$repoRoot = Split-Path $PSScriptRoot -Parent

# Cargar Helpers
$helpersPath = Join-Path $PSScriptRoot "console-helpers.ps1"
if (Test-Path $helpersPath) { . $helpersPath }

# === Buscar packwiz ===
$packwiz = Get-Command packwiz -ErrorAction SilentlyContinue
if (-not $packwiz) {
    # Buscar en tools/
    $localPackwiz = Join-Path $repoRoot "tools\packwiz.exe"
    if (Test-Path $localPackwiz) {
        $packwiz = @{ Source = $localPackwiz }
    }
    else {
        Write-ErrorMsg "packwiz no esta instalado."
        Write-Warn "Corre primero: .\scripts\setup-packwiz.ps1"
        exit 1
    }
}

$packwizPath = if ($packwiz.Source) { $packwiz.Source } else { $packwiz.Path }
Write-Info "Usando packwiz: $packwizPath"

# === Validar directorio del pack ===
if ($PackDir -eq ".\pack") {
    $PackDir = Join-Path $repoRoot "pack"
}
$PackDir = (Resolve-Path $PackDir -ErrorAction SilentlyContinue).Path
if (-not $PackDir -or -not (Test-Path (Join-Path $PackDir "pack.toml"))) {
    Write-ErrorMsg "No se encontro pack.toml en: $PackDir"
    exit 1
}

Write-Info "Directorio del pack: $PackDir"
Write-Host ""

# === Resolver mods bloqueados de CurseForge ===
Write-Info "Resolviendo restricciones de CurseForge..."
$fixScript = Join-Path $PSScriptRoot "fix-blocked-mods.ps1"
if (Test-Path $fixScript) {
    & powershell.exe -ExecutionPolicy Bypass -File $fixScript
}

# === Refresh ===
$success = Show-Spinner -Text "Refrescando index.toml" -Command $packwizPath -Arguments @("refresh") -WorkingDir $PackDir
if (-not $success) {
    Write-ErrorMsg "packwiz refresh fallo."
    exit 1
}

# === Aplicar preserve a configs del jugador ===
Write-Info "Protegiendo configs del jugador..."
$indexPath = Join-Path $PackDir "index.toml"
if (Test-Path $indexPath) {
    $indexContent = Get-Content $indexPath -Raw
    
    $preservePatterns = @(
        'file = "options\.txt"',
        'file = "config/DistantHorizons\.toml"',
        'file = "shaderpacks/.*?\.txt"'
    )
    
    foreach ($pattern in $preservePatterns) {
        $regex = "(?m)($pattern\r?\n\s*hash = `".*?`")(\r?\n\s*preserve = true)*"
        $indexContent = $indexContent -replace $regex, "`$1`r`npreserve = true"
    }
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllText($indexPath, $indexContent, $utf8NoBom)
    Write-Success "preserve = true aplicado"
    
    Show-Spinner -Text "Refrescando de nuevo" -Command $packwizPath -Arguments @("refresh") -WorkingDir $PackDir | Out-Null
}

# === Verificar ===
Write-Info "Verificando consistencia..."

$modCount = (Get-ChildItem (Join-Path $PackDir "mods") -Filter "*.pw.toml" -ErrorAction SilentlyContinue | Measure-Object).Count

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

$looseFiles = @("options.txt", "patchouli_data.json")
foreach ($file in $looseFiles) {
    if (Test-Path (Join-Path $PackDir $file)) {
        $overrideCount++
    }
}

Write-Value "Mods registrados (.pw.toml)" $modCount
Write-Value "Archivos override (configs)" $overrideCount

# === Validar pack.toml ===
Write-Info "Validando pack.toml..."
$packToml = Get-Content (Join-Path $PackDir "pack.toml") -Raw
if ($packToml -match 'minecraft\s*=\s*"1\.20\.1"' -and $packToml -match 'forge\s*=\s*"47\.4\.\d+"') {
    Write-Success "Minecraft: 1.20.1"
    Write-Success "Forge detectado"
}
else {
    Write-Warn "Versiones de Minecraft/Forge no coinciden con lo esperado"
}

Write-Host ""

if ($Serve) {
    Write-Info "Iniciando servidor local de packwiz..."
    Write-Value "URL" "http://localhost:8080/pack.toml"
    Write-Warn "Presiona Ctrl+C para detener"
    Write-Host ""
    Push-Location $PackDir
    try {
        & $packwizPath serve
    }
    finally {
        Pop-Location
    }
}
