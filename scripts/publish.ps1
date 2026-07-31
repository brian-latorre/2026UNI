param (
    [string]$CommitMessage,
    [string]$Version
)

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Importar helpers
. (Join-Path $PSScriptRoot "console-helpers.ps1")

try {
    Write-Banner "1-CLICK UPDATE: 2026UNI MODPACK"
    Write-Info "Iniciando proceso de publicacion..."
    Write-Host ""
    
    # Leer version actual de pack.toml
    $packTomlPath = Join-Path (Split-Path $PSScriptRoot -Parent) "pack\pack.toml"
    $currentVersion = "1.0"
    
    if (Test-Path $packTomlPath) {
        $packTomlContent = Get-Content $packTomlPath -Raw
        if ($packTomlContent -match '(?m)^version\s*=\s*"([^"]+)"') {
            $currentVersion = $matches[1]
        }
    }
    
    # Calcular versión sugerida (inteligente)
    $parts = $currentVersion.Split('.')
    if ($parts.Length -eq 3) {
        if ($parts[2] -eq '0') {
            # Si termina en 0 (ej: 1.1.0), sugerir 1.2.0
            $suggestedVersion = "{0}.{1}.0" -f $parts[0], ([int]$parts[1] + 1)
        } else {
            # Si termina en otro numero (ej: 1.1.1), sugerir 1.1.2
            $suggestedVersion = "{0}.{1}.{2}" -f $parts[0], $parts[1], ([int]$parts[2] + 1)
        }
    } else {
        $lastIdx = $parts.Length - 1
        if ($parts[$lastIdx] -match '^\d+$') {
            $parts[$lastIdx] = ([int]$parts[$lastIdx] + 1).ToString()
            $suggestedVersion = $parts -join '.'
        } else {
            $suggestedVersion = $currentVersion + ".1"
        }
    }

    # Preguntar al usuario por la versión (si no fue pasada como parámetro)
    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host " LA ULTIMA VERSION PUBLICADA FUE: $currentVersion" -ForegroundColor Yellow
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host ""
        $inputVersion = Read-Host "1. Ingrese la version para esta actualizacion [Enter para usar '$suggestedVersion']"
        
        if ([string]::IsNullOrWhiteSpace($inputVersion)) {
            $packVersion = $suggestedVersion
        } else {
            $packVersion = $inputVersion.Trim()
        }
    } else {
        $packVersion = $Version.Trim()
    }
    
    # Preguntar por el mensaje si no se pasó
    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        $inputMessage = Read-Host "2. Escribe un comentario corto de lo que cambiaste (ej: Nuevas imagenes) [Enter por defecto]"
        if ([string]::IsNullOrWhiteSpace($inputMessage)) {
            $CommitMessage = "Actualizacion del modpack"
        } else {
            $CommitMessage = $inputMessage.Trim()
        }
    }
    Write-Host ""

    $startTime = [System.Diagnostics.Stopwatch]::StartNew()
    
    # PASO 1: Sincronizar overrides
    Write-Step 1 4 "Sincronizando overrides locales..."
    $syncScript = Join-Path $PSScriptRoot "sync-overrides.ps1"
    & powershell.exe -ExecutionPolicy Bypass -File $syncScript
    if ($LASTEXITCODE -ne 0) { throw "Fallo al sincronizar overrides." }
    Write-Host ""
    
    # PASO 2: Auto-import de mods (Python)
    Write-Step 2 4 "Auto-detectando nuevos mods..."
    Write-Info "Explicacion: Esto compara los .jar locales que tengas en la carpeta 'mods'"
    Write-Info "contra CurseForge y Modrinth para agregarlos a la lista de auto-actualizacion."
    $pyScript = Join-Path $PSScriptRoot "auto-import-mods.py"
    $env:PYTHONIOENCODING="utf-8"
    $success = Show-Spinner -Text "Analizando mods (puede demorar)" -Command "python" -Arguments @("`"$pyScript`"")
    if (-not $success) { throw "Fallo al importar mods (Python fallo)." }
    Write-Host ""
    
    # PASO 3: Build & Validacion del pack
    Write-Step 3 4 "Construyendo y validando el pack..."
    Write-Info "Explicacion: Esto regenera el indice (index.toml) para que el launcher sepa exactamente"
    Write-Info "que archivos descargar. Luego valida que las versiones de Minecraft coincidan."
    $buildScript = Join-Path $PSScriptRoot "build-pack.ps1"
    & powershell.exe -ExecutionPolicy Bypass -File $buildScript
    if ($LASTEXITCODE -ne 0) { throw "Fallo al construir el pack." }
    Write-Host ""
    
    # PASO 4: Git Push
    Write-Step 4 4 "Preparando subida a la nube..."
    Write-Info "Explicacion: Esto empaqueta tus cambios y los envia a GitHub (origin/main)."
    Write-Info "Tus jugadores recibiran los cambios automaticamente al abrir su launcher."
    
    # Leer y gestionar version de pack.toml
    $packTomlContent = ""
    if (Test-Path $packTomlPath) {
        $packTomlContent = Get-Content $packTomlPath -Raw
        if ($packTomlContent -match '(?m)^version\s*=\s*"[^"]+"') {
            $packTomlContent = $packTomlContent -replace '(?m)^version\s*=\s*"[^"]+"', "version = `"$packVersion`""
        } else {
            # Si no existe, agregarla después de name
            if ($packTomlContent -match '(?m)^name\s*=\s*.*') {
                $packTomlContent = $packTomlContent -replace '(?m)(^name\s*=\s*.*)', "`$1`r`nversion = `"$packVersion`""
            } else {
                $packTomlContent = "version = `"$packVersion`"`r`n" + $packTomlContent
            }
        }
        $utf8NoBom = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllText($packTomlPath, $packTomlContent, $utf8NoBom)
        Write-Success "Archivo pack.toml actualizado con la versión: $packVersion"
        Write-Host ""
    }
    
    # Hacer commit
    $repoRoot = Split-Path $PSScriptRoot -Parent
    Set-Location $repoRoot
    
    $gitAdd = Show-Spinner -Text "Agregando archivos al commit" -Command "git" -Arguments @("add", ".")
    # Ignorar errores de git add (warnings de LF/CRLF)
    
    $fullCommitMsg = "[$packVersion]: $CommitMessage"
    $gitCommit = Show-Spinner -Text "Guardando commit ($fullCommitMsg)" -Command "git" -Arguments @("commit", "-m", "`"$fullCommitMsg`"")
    # git commit returns 1 if nothing to commit, which is fine, but we assume it might fail.
    # Actually, let's just ignore commit failure if it's because there's nothing to commit.
    
    $gitPush = Show-Spinner -Text "Subiendo cambios a GitHub" -Command "git" -Arguments @("push", "origin", "main")
    # Ignorar errores de git porque suele retornar stderr aunque sea exitoso
    
    $startTime.Stop()
    $totalMinutes = $startTime.Elapsed.TotalMinutes
    $totalTimeStr = "{0:N1} min" -f $totalMinutes
    
    $gitShortStat = (git diff HEAD~1 --shortstat) -join ""
    $gitHash = (git rev-parse --short HEAD) -join ""
    
    # Extraer mods añadidos y eliminados
    $gitStatus = git diff HEAD~1 HEAD --name-status
    $addedMods = @()
    $removedMods = @()
    foreach ($line in $gitStatus) {
        if ($line -match "^A\s+(?:pack/)?mods/(.+)(?:\.pw\.toml|\.jar)$") {
            $addedMods += $matches[1]
        }
        elseif ($line -match "^D\s+(?:pack/)?mods/(.+)(?:\.pw\.toml|\.jar)$") {
            $removedMods += $matches[1]
        }
    }
    
    $logPath = Join-Path (Split-Path $PSScriptRoot -Parent) "logs\latest.log"
    Write-Summary -Version $packVersion -GitShortStat $gitShortStat -GitHash $gitHash -Url "https://github.com/brian-latorre/2026UNI" -TotalTime $totalTimeStr -AddedMods $addedMods -RemovedMods $removedMods -LogPath $logPath
    
} catch {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Red
    Write-Host "  ERROR DURANTE LA ACTUALIZACION" -ForegroundColor Red
    Write-Host "=======================================================" -ForegroundColor Red
    Write-Info "Revisa el error rojo de arriba para ver que fallo."
    Write-Host ""
    throw $_
}
