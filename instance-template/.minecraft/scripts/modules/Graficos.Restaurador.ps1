function Restore-Embeddium {
    try {
        $perfil = Get-PerfilActivo
        $src = "$PSScriptRoot\..\..\presets_graficos\$perfil\embeddium-options.json"
        $dest = "$PSScriptRoot\..\..\config\embeddium-options.json"
        
        if (-not (Test-Path $src)) {
            Write-Log -Mensaje "No se encontro plantilla para Restore-Embeddium: $src" -Nivel ERROR
            return $false
        }
        if (Test-Path $dest) {
            Backup-Antes -Ruta $dest
        } else {
            Write-Log -Mensaje "Destino $dest no existe, se creara nuevo." -Nivel WARN
            $destDir = Split-Path $dest
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
        }
        
        Copy-Item -Path $src -Destination $dest -Force
        Write-Log -Mensaje "Restore-Embeddium completado." -Nivel INFO
        return $true
    } catch {
        Write-Log -Mensaje "Error en Restore-Embeddium: $($_.Exception.Message)" -Nivel ERROR
        return $false
    }
}

function Restore-Oculus {
    try {
        $perfil = Get-PerfilActivo
        $src = "$PSScriptRoot\..\..\presets_graficos\$perfil\oculus.properties"
        $dest = "$PSScriptRoot\..\..\config\oculus.properties"
        
        if (-not (Test-Path $src)) {
            Write-Log -Mensaje "No se encontro plantilla para Restore-Oculus: $src" -Nivel ERROR
            return $false
        }
        if (Test-Path $dest) {
            Backup-Antes -Ruta $dest
        } else {
            Write-Log -Mensaje "Destino $dest no existe, se creara nuevo." -Nivel WARN
            $destDir = Split-Path $dest
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
        }
        
        Copy-Item -Path $src -Destination $dest -Force
        Write-Log -Mensaje "Restore-Oculus completado." -Nivel INFO
        return $true
    } catch {
        Write-Log -Mensaje "Error en Restore-Oculus: $($_.Exception.Message)" -Nivel ERROR
        return $false
    }
}

function Restore-OptionsTxt {
    try {
        $perfil = Get-PerfilActivo
        $src = "$PSScriptRoot\..\..\presets_graficos\$perfil\options.txt"
        $dest = "$PSScriptRoot\..\..\options.txt"
        
        if (-not (Test-Path $src)) {
            Write-Log -Mensaje "No se encontro plantilla para Restore-OptionsTxt: $src" -Nivel ERROR
            return $false
        }
        if (Test-Path $dest) {
            Backup-Antes -Ruta $dest
        } else {
            Write-Log -Mensaje "Destino $dest no existe, se creara nuevo." -Nivel WARN
            $destDir = Split-Path $dest
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
        }
        
        Copy-Item -Path $src -Destination $dest -Force
        Write-Log -Mensaje "Restore-OptionsTxt completado." -Nivel INFO
        return $true
    } catch {
        Write-Log -Mensaje "Error en Restore-OptionsTxt: $($_.Exception.Message)" -Nivel ERROR
        return $false
    }
}

function Restore-TodosLosGraficos {
    $r1 = Restore-Embeddium
    $r2 = Restore-Oculus
    $r3 = Restore-OptionsTxt
    if ($r1 -and $r2 -and $r3) {
        Write-Log -Mensaje "Restore-TodosLosGraficos completado exitosamente." -Nivel INFO
        return $true
    } else {
        Write-Log -Mensaje "Restore-TodosLosGraficos termino con errores parciales." -Nivel WARN
        return $false
    }
}
