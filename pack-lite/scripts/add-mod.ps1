<#
.SYNOPSIS
    Agrega un mod al pack de packwiz.
.DESCRIPTION
    Wrapper amigable para agregar un mod desde Modrinth, CurseForge,
    o como descarga directa por URL.
.EXAMPLE
    # Agregar desde Modrinth (por defecto)
    .\add-mod.ps1 -Name "create"
    
    # Agregar desde CurseForge
    .\add-mod.ps1 -Name "jei" -Source curseforge
    
    # Agregar desde URL directa (para mods no indexados)
    .\add-mod.ps1 -Url "https://github.com/user/mod/releases/download/v1.0/mod-1.0.jar"
    
    # Agregar varios mods de Modrinth de una vez
    .\add-mod.ps1 -Name "create", "jei", "jade" -Source modrinth
.NOTES
    Requiere packwiz instalado.
    Después de agregar mods, corre: .\scripts\build-pack.ps1
#>

[CmdletBinding(DefaultParameterSetName = "ByName")]
param(
    # Nombre(s) o slug(s) del mod en Modrinth/CurseForge
    [Parameter(ParameterSetName = "ByName", Position = 0)]
    [string[]]$Name,
    
    # Fuente: modrinth (default) o curseforge
    [Parameter(ParameterSetName = "ByName")]
    [ValidateSet("modrinth", "curseforge")]
    [string]$Source = "modrinth",
    
    # URL directa al archivo .jar del mod
    [Parameter(ParameterSetName = "ByUrl", Mandatory)]
    [string]$Url,
    
    # Directorio del pack
    [string]$PackDir = "$PSScriptRoot\..\pack",
    
    # Versión de Minecraft (para filtrar)
    [string]$GameVersion = "1.20.1"
)

$ErrorActionPreference = "Stop"

# === Buscar packwiz ===
$packwiz = Get-Command packwiz -ErrorAction SilentlyContinue
if (-not $packwiz) {
    $localPackwiz = Join-Path $PSScriptRoot "..\tools\packwiz.exe"
    if (Test-Path $localPackwiz) {
        $packwizPath = $localPackwiz
    }
    else {
        Write-Host "[ERROR] packwiz no está instalado." -ForegroundColor Red
        Write-Host "Corre primero: .\scripts\setup-packwiz.ps1" -ForegroundColor Yellow
        exit 1
    }
}
else {
    $packwizPath = if ($packwiz.Source) { $packwiz.Source } else { $packwiz.Path }
}

$PackDir = Resolve-Path $PackDir
if (-not (Test-Path (Join-Path $PackDir "pack.toml"))) {
    Write-Host "[ERROR] No se encontró pack.toml en: $PackDir" -ForegroundColor Red
    exit 1
}

Push-Location $PackDir
try {
    if ($PSCmdlet.ParameterSetName -eq "ByUrl") {
        # === Agregar por URL directa ===
        Write-Host "[ADD] Agregando mod desde URL..." -ForegroundColor Cyan
        Write-Host "  URL: $Url" -ForegroundColor Gray
        
        & $packwizPath url add $Url
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Mod agregado exitosamente." -ForegroundColor Green
        }
        else {
            Write-Host "[ERROR] Falló al agregar el mod." -ForegroundColor Red
        }
    }
    else {
        # === Agregar por nombre desde Modrinth o CurseForge ===
        $total = $Name.Count
        $success = 0
        $failed = 0
        
        foreach ($modName in $Name) {
            Write-Host "[ADD] $modName ($Source)..." -ForegroundColor Cyan -NoNewline
            
            try {
                if ($Source -eq "modrinth") {
                    & $packwizPath modrinth add $modName 2>&1 | Out-Null
                }
                else {
                    & $packwizPath curseforge add $modName 2>&1 | Out-Null
                }
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host " OK" -ForegroundColor Green
                    $success++
                }
                else {
                    Write-Host " FALLÓ" -ForegroundColor Red
                    $failed++
                    
                    # Sugerir la otra fuente
                    $altSource = if ($Source -eq "modrinth") { "curseforge" } else { "modrinth" }
                    Write-Host "    Intenta con: .\add-mod.ps1 -Name '$modName' -Source $altSource" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host " ERROR: $_" -ForegroundColor Red
                $failed++
            }
        }
        
        Write-Host ""
        if ($total -gt 1) {
            Write-Host "Resultado: $success/$total exitosos" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
        }
    }
    
    Write-Host ""
    Write-Host "[TIP] No olvides hacer 'packwiz refresh' o correr .\scripts\build-pack.ps1" -ForegroundColor DarkGray
}
finally {
    Pop-Location
}
