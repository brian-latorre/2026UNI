param(
    [string]$PackModsDir = "$PSScriptRoot\..\pack\mods",
    [string]$SourceModsDir = "$env:APPDATA\.minecraft\2026UNI\mods"
)

$ErrorActionPreference = "Continue"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Resolviendo mods bloqueados de CurseForge" -ForegroundColor Cyan
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
                    # Mod is blocked!
                    if ($content -match 'filename\s*=\s*"([^"]+)"') {
                        $filename = $matches[1]
                        $sourceJar = Join-Path $SourceModsDir $filename
                        $destJar = Join-Path $PackModsDir $filename
                        
                        Write-Host "[INFO] Mod bloqueado detectado: $filename" -ForegroundColor Yellow
                        if (Test-Path $sourceJar) {
                            Copy-Item $sourceJar $destJar -Force
                            Remove-Item $file.FullName -Force
                            Write-Host "  -> Reemplazado por el .jar local exitosamente." -ForegroundColor Green
                            $fixedCount++
                        } else {
                            Write-Host "  -> [ERROR] No se encontró el .jar local en $sourceJar" -ForegroundColor Red
                        }
                    }
                }
            } catch {
                # Ignore API errors to not block the build
                # Write-Host "  -> [WARN] Error verificando API para $projectId" -ForegroundColor DarkGray
            }
        }
    }
}

if ($fixedCount -gt 0) {
    Write-Host "Se resolvieron $fixedCount mods bloqueados." -ForegroundColor Green
} else {
    Write-Host "Todos los mods están correctos." -ForegroundColor Green
}
Write-Host ""
