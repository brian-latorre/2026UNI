<#
.SYNOPSIS
    Detecta duplicados, archivos basura, y problemas en la carpeta mods/.
.DESCRIPTION
    Analiza la carpeta de mods de tu instancia real de Minecraft y reporta:
    - Archivos duplicados (mismo mod, diferentes versiones)
    - Archivos .input (restos de procesos de firmado/renombrado)
    - Archivos que no son .jar válidos
    - Carpeta .connector/ (caché regenerable)
    - Mods con nombres sospechosos
.NOTES
    NO modifica ni borra nada — solo reporta. Tú decides qué hacer.
#>

[CmdletBinding()]

param(
    [string]$ModsDir = "$env:APPDATA\.minecraft\2026UNI\mods"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ModsDir)) {
    Write-Host "[ERROR] No se encontró la carpeta: $ModsDir" -ForegroundColor Red
    exit 1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Limpieza de mods — 2026UNI" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Carpeta: $ModsDir" -ForegroundColor Gray
Write-Host ""

$issues = @()

# === 1. Archivos .input (basura de firmado/renombrado) ===
Write-Host "[1] Buscando archivos .input..." -ForegroundColor Cyan
$inputFiles = Get-ChildItem $ModsDir -Filter "*.input" -Recurse
if ($inputFiles.Count -gt 0) {
    Write-Host "  ENCONTRADOS: $($inputFiles.Count) archivo(s) .input" -ForegroundColor Red
    foreach ($f in $inputFiles) {
        Write-Host "    ✗ $($f.Name)" -ForegroundColor Red
        $issues += [PSCustomObject]@{
            Tipo = "Basura (.input)"
            Archivo = $f.Name
            Acción = "Eliminar"
        }
    }
}
else {
    Write-Host "  OK — sin archivos .input" -ForegroundColor Green
}

# === 2. Archivos que no son .jar ===
Write-Host ""
Write-Host "[2] Buscando archivos no-.jar en la raíz de mods/..." -ForegroundColor Cyan
$nonJars = Get-ChildItem $ModsDir -File | Where-Object { $_.Extension -notin @(".jar", ".disabled") }
if ($nonJars.Count -gt 0) {
    Write-Host "  ENCONTRADOS: $($nonJars.Count) archivo(s) no-.jar" -ForegroundColor Yellow
    foreach ($f in $nonJars) {
        Write-Host "    ? $($f.Name)" -ForegroundColor Yellow
        $issues += [PSCustomObject]@{
            Tipo = "No es .jar"
            Archivo = $f.Name
            Acción = "Revisar"
        }
    }
}
else {
    Write-Host "  OK — solo hay .jar" -ForegroundColor Green
}

# === 3. Duplicados (mismo mod, diferentes versiones) ===
Write-Host ""
Write-Host "[3] Buscando mods duplicados..." -ForegroundColor Cyan

$jars = Get-ChildItem $ModsDir -Filter "*.jar" -File
$modGroups = @{}

foreach ($jar in $jars) {
    # Extraer nombre base del mod (antes de la versión)
    # Patrones comunes: mod-name-1.2.3.jar, mod_name-mc1.20.1-1.2.3.jar
    $baseName = $jar.BaseName
    
    # Intentar extraer el nombre del mod quitando versiones
    $cleanName = $baseName -replace '-mc\d+\.\d+(\.\d+)?', '' `
                           -replace '-forge-\d+\.\d+(\.\d+)?', '' `
                           -replace '-fabric-\d+\.\d+(\.\d+)?', '' `
                           -replace '-\d+\.\d+\.\d+.*$', '' `
                           -replace '_\d+\.\d+\.\d+.*$', '' `
                           -replace '-v?\d+\.\d+.*$', ''
    
    $cleanName = $cleanName.ToLower().Trim('-').Trim('_')
    
    if (-not $modGroups.ContainsKey($cleanName)) {
        $modGroups[$cleanName] = @()
    }
    $modGroups[$cleanName] += $jar.Name
}

$duplicates = $modGroups.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
if ($duplicates) {
    $dupCount = ($duplicates | Measure-Object).Count
    Write-Host "  ENCONTRADOS: $dupCount grupo(s) con posibles duplicados" -ForegroundColor Yellow
    foreach ($group in $duplicates) {
        Write-Host "    Grupo '$($group.Key)':" -ForegroundColor Yellow
        foreach ($file in $group.Value) {
            Write-Host "      - $file" -ForegroundColor DarkYellow
            $issues += [PSCustomObject]@{
                Tipo = "Posible duplicado"
                Archivo = $file
                Acción = "Revisar — ¿hay dos versiones?"
            }
        }
    }
    Write-Host ""
    Write-Host "  NOTA: Algunos 'duplicados' pueden ser mods diferentes con nombres similares." -ForegroundColor DarkGray
    Write-Host "        Revisa cada grupo manualmente antes de eliminar." -ForegroundColor DarkGray
}
else {
    Write-Host "  OK — sin duplicados detectados" -ForegroundColor Green
}

# === 4. Carpeta .connector/ ===
Write-Host ""
Write-Host "[4] Verificando carpeta .connector/..." -ForegroundColor Cyan
$connectorPath = Join-Path $ModsDir ".connector"
if (Test-Path $connectorPath) {
    $connectorSize = (Get-ChildItem $connectorPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  ENCONTRADA: .connector/ ($([math]::Round($connectorSize, 1)) MB)" -ForegroundColor Yellow
    Write-Host "  Es caché de Sinytra Connector — se regenera sola." -ForegroundColor DarkGray
    Write-Host "  NO incluir en el pack (ya está en .gitignore)." -ForegroundColor DarkGray
}
else {
    Write-Host "  OK — no existe" -ForegroundColor Green
}

# === 5. Mods .disabled ===
Write-Host ""
Write-Host "[5] Verificando mods deshabilitados..." -ForegroundColor Cyan
$disabled = Get-ChildItem $ModsDir -Filter "*.disabled" -File
if ($disabled.Count -gt 0) {
    Write-Host "  ENCONTRADOS: $($disabled.Count) mod(s) deshabilitados" -ForegroundColor Yellow
    foreach ($f in $disabled) {
        Write-Host "    ⊘ $($f.Name)" -ForegroundColor DarkYellow
    }
}
else {
    Write-Host "  OK — sin mods deshabilitados" -ForegroundColor Green
}

# === Resumen ===
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Resumen" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Total .jar:         $($jars.Count)" -ForegroundColor White
Write-Host "  Problemas:          $($issues.Count)" -ForegroundColor $(if ($issues.Count -gt 0) { "Yellow" } else { "Green" })

if ($issues.Count -gt 0) {
    Write-Host ""
    Write-Host "  === Detalle de problemas ===" -ForegroundColor Yellow
    $issues | Format-Table -AutoSize
    
    # Guardar reporte
    $reportPath = Join-Path $PSScriptRoot "..\mods-cleanup-report.txt"
    $issues | Format-Table -AutoSize | Out-String | Out-File $reportPath -Encoding UTF8
    Write-Host "  Reporte guardado en: $reportPath" -ForegroundColor Cyan
}
else {
    Write-Host ""
    Write-Host "  ¡Tu carpeta de mods está limpia!" -ForegroundColor Green
}
