param (
    [string]$CommitMessage,
    [string]$Version,
    [ValidateSet("All","Normal","Lite")]
    [string]$Perfil = "All"
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
    
    # PASO 1: Sincronizar overrides (según perfil)
    Write-Step 1 5 "Sincronizando overrides locales..."
    $syncScript = Join-Path $PSScriptRoot "sync-overrides.ps1"

    $perfilesASincronizar = if ($Perfil -eq "All") { @("Normal","Lite") } else { @($Perfil) }

    foreach ($p in $perfilesASincronizar) {
        Write-Info "Sincronizando perfil: $p"
        & powershell.exe -ExecutionPolicy Bypass -File $syncScript -Perfil $p
        if ($LASTEXITCODE -ne 0) { throw "Fallo al sincronizar overrides del perfil $p." }
    }
    Write-Host ""
    
    # PASO 2: Auto-import de mods (Python)
    Write-Step 2 5 "Auto-detectando nuevos mods..."
    Write-Info "Explicacion: Esto compara los .jar locales que tengas en la carpeta 'mods'"
    Write-Info "contra CurseForge y Modrinth para agregarlos a la lista de auto-actualizacion."
    $pyScript = Join-Path $PSScriptRoot "auto-import-mods.py"
    $env:PYTHONIOENCODING="utf-8"
    
    foreach ($p in $perfilesASincronizar) {
        Write-Info "Importando mods para el perfil: $p"
        
        $sourceModsDir = if ($p -eq "Lite") {
            "$env:APPDATA\.minecraft\2026UNI_Lite\mods"
        } else {
            "$env:APPDATA\.minecraft\2026UNI\mods"
        }
        
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $targetPackDir = if ($p -eq "Lite") { Join-Path $repoRoot "pack-lite" } else { Join-Path $repoRoot "pack" }
        
        $success = Show-Spinner -Text "Analizando mods en $p (puede demorar)" -Command "python" -Arguments @("`"$pyScript`"", "`"$sourceModsDir`"", "`"$targetPackDir`"")
        if (-not $success) { throw "Fallo al importar mods para $p (Python fallo)." }
    }
    Write-Host ""
    
    # PASO 3: Build & Validacion del pack (uno o ambos según perfil)
    Write-Step 3 5 "Construyendo y validando el pack..."
    Write-Info "Explicacion: Esto regenera el indice (index.toml) para que el launcher sepa exactamente"
    Write-Info "que archivos descargar. Luego valida que las versiones de Minecraft coincidan."
    $buildScript = Join-Path $PSScriptRoot "build-pack.ps1"
    $repoRoot = Split-Path $PSScriptRoot -Parent

    foreach ($p in $perfilesASincronizar) {
        $targetPackDir = if ($p -eq "Lite") { Join-Path $repoRoot "pack-lite" } else { Join-Path $repoRoot "pack" }
        Write-Info "Construyendo pack: $p ($targetPackDir)"
        & powershell.exe -ExecutionPolicy Bypass -File $buildScript -PackDir $targetPackDir
        if ($LASTEXITCODE -ne 0) { throw "Fallo al construir el pack $p." }

        # Sincronizar la version en el pack-lite/pack.toml también
        if ($p -eq "Lite") {
            $liteTomlPath = Join-Path $targetPackDir "pack.toml"
            if (Test-Path $liteTomlPath) {
                $liteContent = Get-Content $liteTomlPath -Raw
                $liteContent = $liteContent -replace '(?m)^version\s*=\s*"[^"]+"', "version = `"$packVersion`""
                $utf8NoBom = New-Object System.Text.UTF8Encoding $False
                [System.IO.File]::WriteAllText($liteTomlPath, $liteContent, $utf8NoBom)
            }
        }
    }
    Write-Host ""
    
    # PASO 4: Git Push
    Write-Step 4 5 "Preparando subida a la nube..."
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
        
        # Auto-generar version.json para lectura local en el cliente (Packwiz sí sincroniza .json)
        $repoRoot = Split-Path $PSScriptRoot -Parent
        $jsonContent = @{ version = $packVersion } | ConvertTo-Json

        $dirs = @(
            (Join-Path $repoRoot "pack\config\2026UNI"),
            (Join-Path $repoRoot "pack-lite\config\2026UNI"),
            (Join-Path $repoRoot "instance-template\.minecraft\config\2026UNI")
        )

        foreach ($dir in $dirs) {
            if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
            $vFile = Join-Path $dir "version.json"
            [System.IO.File]::WriteAllText($vFile, $jsonContent, $utf8NoBom)
        }
        
        # Refrescar packwiz en pack y pack-lite para incluir version.json en los index.toml
        Set-Location (Join-Path $repoRoot "pack")
        & (Join-Path $repoRoot "tools\packwiz.exe") refresh | Out-Null

        if (Test-Path (Join-Path $repoRoot "pack-lite")) {
            Set-Location (Join-Path $repoRoot "pack-lite")
            & (Join-Path $repoRoot "tools\packwiz.exe") refresh | Out-Null
        }

        Set-Location $repoRoot
        Write-Success "Archivo version.json generado y sincronizado para todos los packs."
        Write-Host ""
    }
    
    # Hacer commit
    $repoRoot = Split-Path $PSScriptRoot -Parent
    Set-Location $repoRoot
    
    # -----------------------------------------------------------------
    # CONTROL DE ARCHIVOS PESADOS (>95MB) ANTES DE GIT ADD
    # -----------------------------------------------------------------
    $heavyUploadedMods = @()
    foreach ($p in $perfilesASincronizar) {
        $targetPackDir = if ($p -eq "Lite") { Join-Path $repoRoot "pack-lite" } else { Join-Path $repoRoot "pack" }
        $modsPath = Join-Path $targetPackDir "mods"
        
        if (Test-Path $modsPath) {
            $largeJars = Get-ChildItem -Path $modsPath -Filter "*.jar" | Where-Object { $_.Length -gt 95MB }
            
            foreach ($jar in $largeJars) {
                Write-Warn "Mod muy pesado detectado en ${p}: $($jar.Name) ($([math]::Round($jar.Length / 1MB, 2)) MB)"
                if ($githubToken -and $githubRepo) {
                    Write-Step 4 5 "Subiendo $($jar.Name) a GitHub Releases..."
                    $releaseTag = "mods-pesados"
                    $releaseUrl = "https://api.github.com/repos/$githubRepo/releases/tags/$releaseTag"
                    $headers = @{
                        "Authorization" = "token $githubToken"
                        "Accept" = "application/vnd.github.v3+json"
                    }
                    
                    try {
                        $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -ErrorAction Stop
                    } catch {
                        Write-Info "El release no existe, creandolo..."
                        $createUrl = "https://api.github.com/repos/$githubRepo/releases"
                        $body = @{
                            tag_name = $releaseTag
                            name = "Mods Pesados"
                            body = "Almacenamiento automatico de mods >95MB."
                        } | ConvertTo-Json
                        try {
                            $release = Invoke-RestMethod -Uri $createUrl -Method Post -Headers $headers -Body $body -ContentType "application/json" -ErrorAction Stop
                        } catch {
                            throw "Error creando el release en GitHub: $_"
                        }
                    }
                    
                    $uploadUrl = $release.upload_url -replace '\{.*\}$', ''
                    $uploadUrl = "$uploadUrl?name=$($jar.Name)"
                    
                    Write-Info "Subiendo archivo (puede demorar dependiendo de tu conexion)..."
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
                    
                    Write-Info "Vinculando URL con Packwiz en $p..."
                    $packwizExe = Join-Path $repoRoot "tools\packwiz.exe"
                    $modName = $jar.Name -replace '\.jar$', ''
                    
                    Set-Location $targetPackDir
                    $pwArgs = @("url", "add", $modName, $assetUrl)
                    $pwResult = & $packwizExe $pwArgs
                    if ($LASTEXITCODE -ne 0) { throw "Error al vincular el mod pesado con packwiz en $p" }
                    
                    Remove-Item $jar.FullName -Force
                    $heavyUploadedMods += $jar.Name
                    Set-Location $repoRoot
                } else {
                    throw "Falta GITHUB_TOKEN o GITHUB_REPO en .env. El mod $($jar.Name) es de >95MB y rompera Git si no se elimina."
                }
            }
            
            if ($largeJars.Count -gt 0) {
                Set-Location $targetPackDir
                & (Join-Path $repoRoot "tools\packwiz.exe") refresh | Out-Null
                Set-Location $repoRoot
            }
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
    
    # PASO 5: Verificando despliegue remoto en GitHub Actions
    if ($githubToken -and $githubRepo) {
        Write-Step 5 5 "Verificando despliegue en GitHub Actions..."
        $fullGitHash = (git rev-parse HEAD) -join ""
        
        Write-Info "Esperando a que GitHub Actions registre la ejecucion..."
        Start-Sleep -Seconds 5
        
        $runsUrl = "https://api.github.com/repos/$githubRepo/actions/runs?head_sha=$fullGitHash"
        $headers = @{
            "Authorization" = "token $githubToken"
            "Accept" = "application/vnd.github.v3+json"
        }
        
        $maxRetries = 180 # 180 * 5s = 15 minutos de timeout
        $retryCount = 0
        $workflowCompleted = $false
        $workflowSuccess = $false
        $workflowConclusion = ""
        
        Write-Host "    Monitoreando " -NoNewline -ForegroundColor Cyan
        while (-not $workflowCompleted -and $retryCount -lt $maxRetries) {
            try {
                $response = Invoke-RestMethod -Uri $runsUrl -Headers $headers -ErrorAction Stop
                if ($response.total_count -gt 0) {
                    $run = $response.workflow_runs[0]
                    $status = $run.status
                    $workflowConclusion = $run.conclusion
                    
                    if ($status -eq "completed") {
                        $workflowCompleted = $true
                        if ($workflowConclusion -eq "success") {
                            $workflowSuccess = $true
                        }
                    } else {
                        Write-Host "." -NoNewline -ForegroundColor Cyan
                        Start-Sleep -Seconds 5
                    }
                } else {
                    Write-Host "." -NoNewline -ForegroundColor Cyan
                    Start-Sleep -Seconds 5
                }
            } catch {
                Write-Host "!" -NoNewline -ForegroundColor Yellow
                Start-Sleep -Seconds 5
            }
            $retryCount++
        }
        Write-Host ""
        
        if ($workflowCompleted) {
            if ($workflowSuccess) {
                Write-Success "GitHub Actions completo la publicacion con exito."
            } else {
                throw "GitHub Actions reporto un error ($workflowConclusion). Revisa el panel de Actions en GitHub."
            }
        } else {
            throw "Tiempo de espera agotado esperando a GitHub Actions."
        }
        Write-Host ""
    } else {
        Write-Warn "Saltando verificacion remota: Falta GITHUB_TOKEN o GITHUB_REPO en .env."
    }
    
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

