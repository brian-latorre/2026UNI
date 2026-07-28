param(
    [string]$PackModsDir = "$PSScriptRoot\..\pack\mods",
    [string]$SourceModsDir = "$env:APPDATA\.minecraft\2026UNI\mods"
)

$ErrorActionPreference = "Continue"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Resolviendo mods bloqueados (Modo Estricto Local)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

if (-not (Test-Path $SourceModsDir)) {
    Write-Host "[WARN] No se encontró la carpeta de mods original: $SourceModsDir" -ForegroundColor Yellow
    exit 0
}

$tomlFiles = Get-ChildItem -Path $PackModsDir -Filter "*.pw.toml" -ErrorAction SilentlyContinue
$fixedCount = 0

foreach ($file in $tomlFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match 'mode\s*=\s*"metadata:curseforge"') {
        if ($content -match 'project-id\s*=\s*(\d+)') {
            $projectId = $matches[1]
            try {
                $response = Invoke-RestMethod -Uri "https://api.curse.tools/v1/cf/mods/$projectId" -ErrorAction Stop
                if ($response.data.allowModDistribution -eq $false) {
                    # ¡Mod bloqueado!
                    $filename = ""
                    $modName = ""
                    
                    if ($content -match 'filename\s*=\s*"([^"]+)"') { $filename = $matches[1] }
                    if ($content -match 'name\s*=\s*"([^"]+)"') { $modName = $matches[1] }
                    
                    $destJar = Join-Path $PackModsDir $filename
                    Write-Host "[INFO] Mod bloqueado detectado: $filename" -ForegroundColor Yellow
                    
                    # 1. Búsqueda exacta (como funcionaba antes)
                    $sourceJar = Join-Path $SourceModsDir $filename
                    
                    # 2. BÚSQUEDA INTELIGENTE (LA RUTA MANDA)
                    # Si el nombre de CurseForge no coincide con tu .jar local, lo buscamos a la fuerza
                    if (-not (Test-Path $sourceJar)) {
                        # Convertimos "Dye Depot" en un buscador salvaje "*Dye*Depot*.jar"
                        $searchPattern = "*" + ($modName -replace '[^a-zA-Z0-9]', '*') + "*.jar"
                        $possibleJars = Get-ChildItem -Path $SourceModsDir -Filter $searchPattern
                        
                        if ($possibleJars.Count -eq 1) {
                            $sourceJar = $possibleJars[0].FullName
                            # Sobreescribimos el destino para usar el nombre de TU archivo real
                            $destJar = Join-Path $PackModsDir $possibleJars[0].Name
                            Write-Host "  -> Búsqueda inteligente encontró tu .jar real: $($possibleJars[0].Name)" -ForegroundColor Cyan
                        } elseif ($possibleJars.Count -gt 1) {
                            Write-Host "  -> [ERROR] Hay varios archivos parecidos a $modName. Elimina los duplicados." -ForegroundColor Red
                        }
                    }

                    # Ejecución implacable
                    if (Test-Path $sourceJar) {
                        Copy-Item $sourceJar $destJar -Force
                        Remove-Item $file.FullName -Force
                        Write-Host "  -> Reemplazado por tu .jar local exitosamente." -ForegroundColor Green
                        $fixedCount++
                    } else {
                        Write-Host "  -> [ERROR] No se encontró ningún .jar equivalente en tu carpeta local." -ForegroundColor Red
                    }
                }
            } catch {
                # Ignorar errores de la API para no frenar la compilación
            }
        }
    }
}

if ($fixedCount -gt 0) {
    Write-Host "Se forzaron y resolvieron $fixedCount mods." -ForegroundColor Green
} else {
    Write-Host "Todos los mods están correctos." -ForegroundColor Green
}
Write-Host ""