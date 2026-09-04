function Find-InstanceCfg {
    $current = $PSScriptRoot
    for ($i = 0; $i -lt 6; $i++) {
        $check = Join-Path $current "instance.cfg"
        if (Test-Path $check) {
            return $check
        }
        $current = Split-Path $current -Parent
        if (-not $current) { break }
    }

    $fallback = "$env:APPDATA\.minecraft\2026UNI_Launcher\PineconeMC\instances\2026UNI\instance.cfg"
    if (Test-Path $fallback) {
        return $fallback
    }

    Write-Log -Mensaje "No se pudo encontrar instance.cfg ni en ruta relativa ni en APPDATA." -Nivel WARN
    return $null
}

function Test-InstanceCfgPrereqs {
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Contenido
    )
    $hasOverride = $false
    $hasGC = $false
    foreach ($line in $Contenido) {
        if ($line -match "^OverrideJavaArgs=true") { $hasOverride = $true }
        if ($line -match "^GarbageCollectorPreset=None") { $hasGC = $true }
    }
    if (-not ($hasOverride -and $hasGC)) {
        Write-Log -Mensaje "Requisitos de instance.cfg fallaron: OverrideJavaArgs=true o GarbageCollectorPreset=None faltante." -Nivel ERROR
        return $false
    }
    return $true
}

function Set-MotorGC {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("ZGC","G1GC")]
        [string]$Motor
    )
    try {
        $cfg = Find-InstanceCfg
        if (-not $cfg -or -not (Test-Path $cfg)) { return $false }

        $content = Get-Content $cfg
        if (-not (Test-InstanceCfgPrereqs -Contenido $content)) { return $false }

        Backup-Antes -Ruta $cfg

        $newContent = @()
        foreach ($line in $content) {
            if ($line -match "^JvmArgs=`"(.*)`"$") {
                $argsInQuotes = $matches[1]
                if ($Motor -eq "ZGC") {
                    $argsInQuotes = $argsInQuotes -replace "-XX:\+UseG1GC", ""
                    if ($argsInQuotes -notmatch "-XX:\+UseZGC") { $argsInQuotes = "-XX:+UseZGC -XX:+ZGenerational $argsInQuotes" }
                } else {
                    $argsInQuotes = $argsInQuotes -replace "-XX:\+UseZGC", ""
                    $argsInQuotes = $argsInQuotes -replace "-XX:\+ZGenerational", ""
                    if ($argsInQuotes -notmatch "-XX:\+UseG1GC") { $argsInQuotes = "-XX:+UseG1GC $argsInQuotes" }
                }
                $argsInQuotes = $argsInQuotes -replace "\s+", " "
                $argsInQuotes = $argsInQuotes.Trim()
                $newContent += "JvmArgs=`"$argsInQuotes`""
            } else {
                $newContent += $line
            }
        }
        Set-Content -Path $cfg -Value $newContent -Force
        Write-Log -Mensaje "Motor GC cambiado a $Motor" -Nivel INFO
        return $true
    } catch {
        Write-Log -Mensaje "Error al cambiar motor GC: $($_.Exception.Message)" -Nivel ERROR
        return $false
    }
}

function Get-RAMRecomendada {
    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $totalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $reserva = switch ($totalGB) {
        { $_ -le 8 }  { 2.5; break }
        { $_ -le 16 } { 4;   break }
        { $_ -le 32 } { 6;   break }
        default       { 8 }
    }
    $recomendado = [math]::Floor($totalGB - $reserva)
    $recomendado = [math]::Max(4, [math]::Min($recomendado, 10))
    return [PSCustomObject]@{
        TotalGB     = $totalGB
        FreeGB      = $freeGB
        Recomendado = $recomendado
        Advertencia = ($freeGB -lt ($recomendado + 1))
    }
}

function Set-RAM {
    param (
        [Parameter(Mandatory=$true)]
        [int]$GB
    )
    try {
        $cfg = Find-InstanceCfg
        if (-not $cfg -or -not (Test-Path $cfg)) { return $false }

        Backup-Antes -Ruta $cfg
        $mb = $GB * 1024
        
        $content = Get-Content $cfg
        
        # 1. Forzar OverrideMemory=true
        if ($content -match "(?m)^OverrideMemory=.*") {
            $content = $content -replace "(?m)^OverrideMemory=.*", "OverrideMemory=true"
        } else {
            $content += "OverrideMemory=true"
        }
        
        # 2. Asignar MaxMemAlloc
        if ($content -match "(?m)^MaxMemAlloc=.*") {
            $content = $content -replace "(?m)^MaxMemAlloc=.*", "MaxMemAlloc=$mb"
        } else {
            $content += "MaxMemAlloc=$mb"
        }
        
        # 3. Asignar MinMemAlloc
        if ($content -match "(?m)^MinMemAlloc=.*") {
            $content = $content -replace "(?m)^MinMemAlloc=.*", "MinMemAlloc=$mb"
        } else {
            $content += "MinMemAlloc=$mb"
        }

        Set-Content -Path $cfg -Value $content -Force
        Write-Log -Mensaje "RAM asignada a $GB GB ($mb MB)" -Nivel INFO
        return $true
    } catch {
        Write-Log -Mensaje "Error al asignar RAM: $($_.Exception.Message)" -Nivel ERROR
        return $false
    }
}
