<#
.SYNOPSIS
    Funciones de ayuda para estandarizar la salida de consola con colores.
#>

function Write-Banner {
    param([string]$Text)
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([int]$Current, [int]$Total, [string]$Text)
    Write-Host "[$Current/$Total] $Text" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "  [WARN] $Text" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Text)
    Write-Host "  [ERROR] $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "  $Text" -ForegroundColor DarkGray
}

function Write-Value {
    param([string]$Key, [string]$Value)
    Write-Host "  ${Key}: " -ForegroundColor DarkGray -NoNewline
    Write-Host $Value -ForegroundColor White
}

function Show-Spinner {
    param(
        [string]$Text,
        [string]$Command,
        [string[]]$Arguments,
        [string]$WorkingDir = $PWD.Path
    )
    
    Write-Host "  $Text " -ForegroundColor Cyan -NoNewline
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    $process = Start-Process -FilePath $Command -ArgumentList $Arguments -WorkingDirectory $WorkingDir -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\spinner_out.txt" -RedirectStandardError "$env:TEMP\spinner_err.txt"
    
    $spinChars = @("-", "\", "|", "/")
    $i = 0
    
    $interactive = $true
    try {
        $origPos = [Console]::CursorLeft
        $origTop = [Console]::CursorTop
    } catch {
        $interactive = $false
    }
    
    $dotsCounter = 0
    while (-not $process.HasExited) {
        if ($interactive) {
            [Console]::SetCursorPosition($origPos, $origTop)
            Write-Host $spinChars[$i] -ForegroundColor Yellow -NoNewline
            $i = ($i + 1) % 4
        } else {
            if ($dotsCounter % 10 -eq 0) { Write-Host "." -ForegroundColor Yellow -NoNewline }
            $dotsCounter++
        }
        Start-Sleep -Milliseconds 100
    }
    
    if ($interactive) {
        [Console]::SetCursorPosition($origPos, $origTop)
    } else {
        Write-Host " " -NoNewline
    }
    
    $process.WaitForExit()
    $sw.Stop()
    $time = "{0:N1}s" -f $sw.Elapsed.TotalSeconds
    
    $exitCode = $process.ExitCode
    $err = Get-Content "$env:TEMP\spinner_err.txt" -Raw -ErrorAction SilentlyContinue
    
    if ($null -eq $exitCode) {
        if ([string]::IsNullOrWhiteSpace($err)) {
            $exitCode = 0
        } else {
            $exitCode = 1
        }
    }
    
    if ($exitCode -eq 0) {
        Write-Host "OK ($time)   " -ForegroundColor Green
        return $true
    } else {
        Write-Host "FAIL ($time) (Code: $exitCode)" -ForegroundColor Red
        if ($err) { Write-ErrorMsg $err }
        return $false
    }
}

function Write-Summary {
    param(
        [string]$Version,
        [string]$GitShortStat,
        [string]$GitHash,
        [string]$Url,
        [string]$TotalTime,
        [string[]]$AddedMods = @(),
        [string[]]$RemovedMods = @(),
        [string[]]$UpdatedMods = @(),
        [string[]]$RawJars = @(),
        [string[]]$HeavyUploadedMods = @(),
        [string]$LogPath = ""
    )
    
    # Preparamos el contenido para el log (sin colores)
    $logLines = @()
    $logLines += "======================================================="
    $logLines += "  RESUMEN FINAL DE ACTUALIZACION: v$Version"
    $logLines += "======================================================="
    $logLines += "Tiempo total: $TotalTime"
    $logLines += "Commit Hash: $GitHash"
    $logLines += "URL de destino: $Url"
    $logLines += "Cambios detectados (Git): $GitShortStat"
    $logLines += "-------------------------------------------------------"

    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host "  RESUMEN FINAL" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    
    Write-Value "Version publicada" $Version
    Write-Value "Cambios (Git)" $GitShortStat
    
    if ($AddedMods.Count -gt 0) {
        Write-Value "Nuevos Mods Integrados" ($AddedMods.Count)
        $logLines += "NUEVOS MODS INTEGRADOS ($($AddedMods.Count)):"
        foreach ($mod in $AddedMods) {
            Write-Host "    + $mod" -ForegroundColor Green
            $logLines += "  + $mod"
        }
    }
    
    if ($RemovedMods.Count -gt 0) {
        Write-Value "Mods Eliminados" ($RemovedMods.Count)
        $logLines += "MODS ELIMINADOS ($($RemovedMods.Count)):"
        foreach ($mod in $RemovedMods) {
            Write-Host "    - $mod" -ForegroundColor Red
            $logLines += "  - $mod"
        }
    }
    
    if ($UpdatedMods.Count -gt 0) {
        Write-Value "Mods Actualizados" ($UpdatedMods.Count)
        $logLines += "MODS ACTUALIZADOS ($($UpdatedMods.Count)):"
        foreach ($mod in $UpdatedMods) {
            Write-Host "    ~ $mod" -ForegroundColor Cyan
            $logLines += "  ~ $mod"
        }
    }
    
    if ($RawJars.Count -gt 0) {
        Write-Value "Mods Crudos (.jar sin auto-update)" ($RawJars.Count)
        $logLines += "MODS CRUDOS (.jar locales) ($($RawJars.Count)):"
        foreach ($mod in $RawJars) {
            Write-Host "    ! $mod" -ForegroundColor Yellow
            $logLines += "  ! $mod (Advertencia: Sin auto-actualización)"
        }
    }
    
    if ($HeavyUploadedMods.Count -gt 0) {
        Write-Value "Mods Pesados Subidos (>95MB)" ($HeavyUploadedMods.Count)
        $logLines += "MODS PESADOS (>95MB) SUBIDOS AUTOMATICAMENTE ($($HeavyUploadedMods.Count)):"
        foreach ($mod in $HeavyUploadedMods) {
            Write-Host "    ^ $mod" -ForegroundColor Magenta
            $logLines += "  ^ $mod (Subido a GitHub Releases y vinculado)"
        }
    }
    
    Write-Value "Commit Hash" $GitHash
    Write-Value "URL de destino" $Url
    Write-Value "Tiempo total" $TotalTime
    Write-Host ""
    Write-Host "  Actualizacion publicada con exito!" -ForegroundColor Green
    
    $logLines += "======================================================="
    $logLines += "  Actualizacion publicada con exito."
    $logLines += ""
    
    if ($LogPath) {
        # Escribimos los logs recolectados usando UTF8 (añadiendo al final del log de auto-import)
        $logLines | Out-File -FilePath $LogPath -Encoding UTF8 -Append
        Write-Host "  Log completo guardado en: $LogPath" -ForegroundColor DarkGray
    }
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""
}
