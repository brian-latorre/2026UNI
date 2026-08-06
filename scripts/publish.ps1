param (
    [string]$CommitMessage,
    [string]$Version
)

$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Importar helpers
. (Join-Path $PSScriptRoot "console-helpers.ps1")

# Leer credenciales para GitHub Releases
$githubToken = ""
$githubRepo = ""
$envPath = Join-Path (Split-Path $PSScriptRoot -Parent) ".env"
if (Test-Path $envPath) {
    $envLines = Get-Content $envPath
    foreach ($line in $envLines) {
        if ($line -match "^GITHUB_TOKEN=(.+)") { $githubToken = $matches[1].Trim() }
        if ($line -match "^GITHUB_REPO=(.+)") { $githubRepo = $matches[1].Trim() }
    }
}

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
    
    # -----------------------------------------------------------------
    # CONTROL DE ARCHIVOS PESADOS (>95MB) ANTES DE GIT ADD
    # -----------------------------------------------------------------
    $heavyUploadedMods = @()
    $modsPath = Join-Path $repoRoot "pack\mods"
    if (Test-Path $modsPath) {
        $largeJars = Get-ChildItem -Path $modsPath -Filter "*.jar" | Where-Object { $_.Length -gt 95MB }
        
        foreach ($jar in $largeJars) {
            Write-Warn "Mod muy pesado detectado: $($jar.Name) ($([math]::Round($jar.Length / 1MB, 2)) MB)"
            if ($githubToken -and $githubRepo) {
                Write-Step 4 5 "Subiendo $($jar.Name) a GitHub Releases..."
                $releaseTag = "mods-pesados"
                $releaseUrl = "https://api.github.com/repos/$githubRepo/releases/tags/$releaseTag"
                $headers = @{
                    "Authorization" = "token $githubToken"
                    "Accept" = "application/vnd.github.v3+json"
                }
                
                # Check if release exists
                $release = $null
                try {
                    $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -ErrorAction Stop
                } catch {
                    # Create release if not found
                    $createUrl = "https://api.github.com/repos/$githubRepo/releases"
                    $body = @{
                        tag_name = $releaseTag
                        name = "Heavy Mods Storage"
                        body = "Almacenamiento automático de mods >95MB."
                    } | ConvertTo-Json
                    try {
                        $release = Invoke-RestMethod -Uri $createUrl -Method Post -Headers $headers -Body $body -ContentType "application/json" -ErrorAction Stop
                    } catch {
                        throw "Error creando el release en GitHub: $_"
                    }
                }
                
                $uploadUrl = $release.upload_url -replace '\{.*\}$', ''
                $uploadUrl = "$uploadUrl?name=$($jar.Name)"
                
                Write-Info "Subiendo archivo (puede demorar dependiendo de tu conexión)..."
                $uploadHeaders = @{
                    "Authorization" = "token $githubToken"
                    "Accept" = "application/vnd.github.v3+json"
                    "Content-Type" = "application/java-archive"
                }
                
                try {
                    Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $uploadHeaders -InFile $jar.FullName -TimeoutSec 1200 -ErrorAction Stop | Out-Null
                } catch {
                    if ($_.Exception.Message -match "already_exists") {
                        Write-Info "El archivo ya existe en GitHub Releases, enlazando directamente..."
                    } else {
                        throw "Error subiendo el asset: $_"
                    }
                }
                
                $assetUrl = "https://github.com/$githubRepo/releases/download/$releaseTag/$($jar.Name)"
                Write-Success "Subida exitosa."
                
                Write-Info "Vinculando URL con Packwiz..."
                $packwizExe = Join-Path $repoRoot "tools\packwiz.exe"
                $modName = $jar.Name -replace '\.jar$', ''
                
                Set-Location (Join-Path $repoRoot "pack")
                $pwArgs = @("url", "add", $modName, $assetUrl)
                $pwResult = & $packwizExe $pwArgs
                if ($LASTEXITCODE -ne 0) { throw "Error al vincular el mod pesado con packwiz" }
                
                Remove-Item $jar.FullName -Force
                $heavyUploadedMods += $jar.Name
                Set-Location $repoRoot
            } else {
                throw "Falta GITHUB_TOKEN o GITHUB_REPO en .env. El mod $($jar.Name) es de >95MB y rompera Git si no se elimina."
            }
        }
        
        if ($largeJars.Count -gt 0) {
            Set-Location (Join-Path $repoRoot "pack")
            & (Join-Path $repoRoot "tools\packwiz.exe") refresh | Out-Null
            Set-Location $repoRoot
        }
    }
    # -----------------------------------------------------------------

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
    
    # Extraer mods añadidos, eliminados, actualizados y crudos
    $gitStatus = git diff HEAD~1 HEAD --name-status
    $addedMods = @()
    $removedMods = @()
    $updatedMods = @()
    $rawJars = @()
    
    foreach ($line in $gitStatus) {
        if ($line -match "^A\s+(?:pack/)?mods/(.+)\.pw\.toml$") {
            $addedMods += $matches[1]
        }
        elseif ($line -match "^A\s+(?:pack/)?mods/(.+)\.jar$") {
            $rawJars += $matches[1] + ".jar"
        }
        elseif ($line -match "^D\s+(?:pack/)?mods/(.+)(?:\.pw\.toml|\.jar)$") {
            $removedMods += $matches[1]
        }
        elseif ($line -match "^M\s+((?:pack/)?mods/(.+)\.pw\.toml)$") {
            $fullPath = $matches[1]
            $modBaseName = $matches[2]
            
            $oldVer = ""
            $newVer = ""
            
            # Use ErrorAction to silently ignore if git show fails (e.g., file didn't exist in HEAD~1 somehow)
            $oldContent = git show "HEAD~1:$fullPath" 2>$null
            if ($oldContent -match '(?m)^version\s*=\s*"([^"]+)"') { $oldVer = $matches[1] }
            
            $newContent = git show "HEAD:$fullPath" 2>$null
            if ($newContent -match '(?m)^version\s*=\s*"([^"]+)"') { $newVer = $matches[1] }
            
            if ($oldVer -and $newVer -and $oldVer -ne $newVer) {
                $updatedMods += "$modBaseName ($oldVer -> $newVer)"
            } else {
                $updatedMods += "$modBaseName (Cambios internos)"
            }
        }
    }
    
    $logPath = Join-Path (Split-Path $PSScriptRoot -Parent) "logs\latest.log"
    Write-Summary -Version $packVersion -GitShortStat $gitShortStat -GitHash $gitHash -Url "https://github.com/$githubRepo" -TotalTime $totalTimeStr -AddedMods $addedMods -RemovedMods $removedMods -UpdatedMods $updatedMods -RawJars $rawJars -HeavyUploadedMods $heavyUploadedMods -LogPath $logPath
    
} catch {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Red
    Write-Host "  ERROR DURANTE LA ACTUALIZACION" -ForegroundColor Red
    Write-Host "=======================================================" -ForegroundColor Red
    Write-Info "Revisa el error rojo de arriba para ver que fallo."
    Write-Host ""
    throw $_
}
