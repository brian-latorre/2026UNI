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
    # Eliminar carpetas conflictivas o no oficiales para forzar la restauracion mediante Packwiz
    $foldersToRemove = @("config", "mods", "emojiful", "options.txt")
    
    foreach ($folder in $foldersToRemove) {
        $path = "$PSScriptRoot\..\..\$folder"
        if (Test-Path $path) {
            $smartKeyBackup = $null
            $smartKeyClient = Join-Path $path "smartkeysync\client.json"
            
            # Preservar client.json de SmartKeySync para no perder teclas blindadas
            if ($folder -eq "config" -and (Test-Path $smartKeyClient)) {
                $smartKeyBackup = Join-Path ([System.IO.Path]::GetTempPath()) "smartkeysync_client_$([System.Guid]::NewGuid().ToString('N')).json"
                Copy-Item -Path $smartKeyClient -Destination $smartKeyBackup -Force
                Write-Log -Mensaje "Copia temporal de smartkeysync/client.json creada para preservar candados" -Nivel INFO
            }

            Write-Log -Mensaje "Eliminando $folder para restauracion general" -Nivel INFO
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue

            # Restaurar client.json de SmartKeySync
            if ($smartKeyBackup -and (Test-Path $smartKeyBackup)) {
                $destDir = Split-Path $smartKeyClient
                if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
                Copy-Item -Path $smartKeyBackup -Destination $smartKeyClient -Force
                Remove-Item -Path $smartKeyBackup -Force -ErrorAction SilentlyContinue
                Write-Log -Mensaje "SmartKeySync client.json restaurado exitosamente (candados protegidos)" -Nivel INFO
            }
        }
    }

    # Restaura las configs por default de UI/Rendimiento (las crea de nuevo si config/ fue eliminado)
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
