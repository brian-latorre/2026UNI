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

function Find-PrismCfg {
    $current = $PSScriptRoot
    for ($i = 0; $i -lt 6; $i++) {
        $check1 = Join-Path $current "elyprismlauncher.cfg"
        $check2 = Join-Path $current "prismlauncher.cfg"
        if (Test-Path $check1) { return $check1 }
        if (Test-Path $check2) { return $check2 }
        $current = Split-Path $current -Parent
        if (-not $current) { break }
    }

    $fallback = "$env:APPDATA\.minecraft\2026UNI_Launcher\PineconeMC\elyprismlauncher.cfg"
    if (Test-Path $fallback) { return $fallback }
    return $null
}

function Set-RAM {
    param (
        [Parameter(Mandatory=$true)]
        [int]$GB
    )
    try {
        $mb = $GB * 1024
        
        # 1. Asegurar que la instancia delegue la memoria al launcher global (OverrideMemory=false)
        $instCfg = Find-InstanceCfg
        if ($instCfg -and (Test-Path $instCfg)) {
            $content = Get-Content $instCfg
            if ($content -match "(?m)^OverrideMemory=.*") {
                $content = $content -replace "(?m)^OverrideMemory=.*", "OverrideMemory=false"
            } else {
                $content += "OverrideMemory=false"
            }
            Set-Content -Path $instCfg -Value $content -Force
        }

        # 2. Asignar la memoria en el archivo Global del Launcher
        $prismCfg = Find-PrismCfg
        if (-not $prismCfg -or -not (Test-Path $prismCfg)) {
            Write-Log -Mensaje "No se encontró el archivo global del launcher (elyprismlauncher.cfg)." -Nivel ERROR
            return $false
        }

        Backup-Antes -Ruta $prismCfg
        
        $prismContent = Get-Content $prismCfg
        
        if ($prismContent -match "(?m)^MaxMemAlloc=.*") {
            $prismContent = $prismContent -replace "(?m)^MaxMemAlloc=.*", "MaxMemAlloc=$mb"
        } else {
            $prismContent += "MaxMemAlloc=$mb"
        }
        
        if ($prismContent -match "(?m)^MinMemAlloc=.*") {
            $prismContent = $prismContent -replace "(?m)^MinMemAlloc=.*", "MinMemAlloc=$mb"
        } else {
            $prismContent += "MinMemAlloc=$mb"
        }

        Set-Content -Path $prismCfg -Value $prismContent -Force
        Write-Log -Mensaje "RAM Global de Pinecone asignada a $GB GB ($mb MB)" -Nivel INFO
        return $true
    } catch {
        Write-Log -Mensaje "Error al asignar RAM: $($_.Exception.Message)" -Nivel ERROR
        return $false
    }
}
