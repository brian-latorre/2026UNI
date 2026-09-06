<#
.SYNOPSIS
    Importa mods desde el manifest.json de CurseForge y detecta mods sin registrar.
.DESCRIPTION
    1. Lee el manifest.json de CurseForge para obtener los project/file IDs
    2. Intenta agregar cada mod al pack via 'packwiz curseforge add'
    3. Compara la carpeta mods/ real contra los .pw.toml existentes
    4. Genera un reporte de mods que necesitan resolución manual

    NOTA: Tu modpack no viene de CurseForge — lo armas tú bajando cada mod manualmente.
    El manifest.json solo tiene 70 de tus 264 mods. Los demás (la mayoría de Modrinth)
    se tienen que agregar por separado con add-mod.ps1.
.NOTES
    Requiere packwiz instalado.
    Ejecutar desde la raíz del proyecto.
#>

[CmdletBinding()]
param(
    # Ruta al manifest.json de CurseForge
    [string]$ManifestPath = "$env:APPDATA\.minecraft\2026UNI\manifest.json",
    
    # Ruta a la carpeta mods/ real
    [string]$ModsSourceDir = "$env:APPDATA\.minecraft\2026UNI\mods",
    
    # Ruta al directorio pack/
    [string]$PackDir = "$PSScriptRoot\..\pack",
    
    # Solo mostrar qué haría
    [switch]$DryRun,
    
    # Saltar la importación del manifest y solo hacer el reporte de detección
    [switch]$DetectOnly
)

$ErrorActionPreference = "Stop"

# === Buscar packwiz ===
$packwiz = Get-Command packwiz -ErrorAction SilentlyContinue
if (-not $packwiz -and -not $DryRun) {
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

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Importación de mods — 2026UNI" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# =============================================
# PARTE 1: Importar desde manifest.json
# =============================================
if (-not $DetectOnly) {
    Write-Host "[FASE 1] Importando desde manifest.json de CurseForge..." -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Path $ManifestPath)) {
        Write-Host "[WARN] No se encontró manifest.json en: $ManifestPath" -ForegroundColor Yellow
        Write-Host "       Saltando importación de CurseForge." -ForegroundColor Yellow
    }
    else {
        $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
        $totalFiles = $manifest.files.Count
        Write-Host "  Mods en manifest: $totalFiles" -ForegroundColor White
        Write-Host ""
        
        $imported = 0
        $failed = 0
        $failedList = @()
        
        foreach ($entry in $manifest.files) {
            $projectId = $entry.projectID
            $fileId = $entry.fileID
            
            Write-Host "  [$($imported + $failed + 1)/$totalFiles] ProjectID=$projectId FileID=$fileId..." -ForegroundColor Gray -NoNewline
            
            if ($DryRun) {
                Write-Host " (dry run)" -ForegroundColor Yellow
                $imported++
                continue
            }
            
            try {
                Push-Location $PackDir
                # packwiz curseforge add acepta URLs de CurseForge
                $cfUrl = "https://www.curseforge.com/minecraft/mc-mods/project-$projectId"
                & $packwizPath curseforge add $cfUrl --file-id $fileId 2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host " OK" -ForegroundColor Green
                    $imported++
                }
                else {
                    Write-Host " FALLÓ" -ForegroundColor Red
                    $failed++
                    $failedList += [PSCustomObject]@{
                        ProjectID = $projectId
                        FileID = $fileId
                        Reason = "packwiz exit code $LASTEXITCODE"
                    }
                }
            }
            catch {
                Write-Host " ERROR: $_" -ForegroundColor Red
                $failed++
                $failedList += [PSCustomObject]@{
                    ProjectID = $projectId
                    FileID = $fileId
                    Reason = $_.Exception.Message
                }
            }
            finally {
                Pop-Location
            }
        }
        
        Write-Host ""
        Write-Host "  Importados: $imported / $totalFiles" -ForegroundColor $(if ($imported -eq $totalFiles) { "Green" } else { "Yellow" })
        if ($failed -gt 0) {
            Write-Host "  Fallidos:   $failed" -ForegroundColor Red
            Write-Host ""
            Write-Host "  Mods que fallaron:" -ForegroundColor Red
            $failedList | Format-Table -AutoSize
        }
    }
}

# =============================================
# PARTE 2: Detectar mods sin registrar
# =============================================
Write-Host ""
Write-Host "[FASE 2] Detectando mods sin registrar en packwiz..." -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ModsSourceDir)) {
    Write-Host "[ERROR] No se encontró la carpeta mods en: $ModsSourceDir" -ForegroundColor Red
    exit 1
}

# Obtener todos los .jar de la instancia real
$realMods = Get-ChildItem $ModsSourceDir -Filter "*.jar" | Select-Object -ExpandProperty Name | Sort-Object

# Obtener todos los .pw.toml ya registrados en packwiz
$packModsDir = Join-Path $PackDir "mods"
$registeredMods = @()
if (Test-Path $packModsDir) {
    $registeredMods = Get-ChildItem $packModsDir -Filter "*.pw.toml" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match 'filename\s*=\s*"([^"]+)"') {
            $matches[1]
        }
        else {
            $_.BaseName
        }
    }
}

# Comparar
$unmatched = @()
$matched = @()

foreach ($jar in $realMods) {
    $jarBase = [System.IO.Path]::GetFileNameWithoutExtension($jar)
    
    # Intentar match por nombre de archivo
    $isRegistered = $false
    foreach ($reg in $registeredMods) {
        $regBase = [System.IO.Path]::GetFileNameWithoutExtension($reg)
        if ($jar -eq $reg -or $jarBase -like "$regBase*" -or $regBase -like "$jarBase*") {
            $isRegistered = $true
            break
        }
    }
    
    if ($isRegistered) {
        $matched += $jar
    }
    else {
        $unmatched += $jar
    }
}

Write-Host "  Total mods en instancia:     $($realMods.Count)" -ForegroundColor White
Write-Host "  Registrados en packwiz:       $($matched.Count)" -ForegroundColor Green
Write-Host "  Sin registrar (necesitan atención): $($unmatched.Count)" -ForegroundColor $(if ($unmatched.Count -gt 0) { "Yellow" } else { "Green" })

if ($unmatched.Count -gt 0) {
    Write-Host ""
    Write-Host "  === Mods sin registrar ===" -ForegroundColor Yellow
    Write-Host "  Para cada uno, intenta agregarlo con:" -ForegroundColor Yellow
    Write-Host "    .\scripts\add-mod.ps1 -Name '<slug-o-nombre>'" -ForegroundColor Yellow
    Write-Host ""
    
    # Generar reporte
    $reportPath = Join-Path $PSScriptRoot "..\unmatched-mods.txt"
    $reportContent = @()
    $reportContent += "# Mods sin registrar en packwiz — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    $reportContent += "# Total: $($unmatched.Count) de $($realMods.Count)"
    $reportContent += "#"
    $reportContent += "# Para agregar desde Modrinth:  .\scripts\add-mod.ps1 -Name '<slug>' -Source modrinth"
    $reportContent += "# Para agregar desde CurseForge: .\scripts\add-mod.ps1 -Name '<slug>' -Source curseforge"
    $reportContent += "# Para agregar desde URL directa: .\scripts\add-mod.ps1 -Url '<url-del-jar>'"
    $reportContent += ""
    
    foreach ($mod in $unmatched) {
        # Intentar extraer nombre limpio del filename
        $cleanName = $mod -replace '-forge-.*$', '' -replace '-fabric-.*$', '' -replace '-mc\d.*$', '' -replace '-\d+\.\d+.*$', '' -replace '_\d+\.\d+.*$', ''
        $reportContent += "$mod"
        Write-Host "    $mod" -ForegroundColor DarkYellow
    }
    
    $reportContent | Out-File $reportPath -Encoding UTF8
    Write-Host ""
    Write-Host "  Reporte guardado en: $reportPath" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Importación completa" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
