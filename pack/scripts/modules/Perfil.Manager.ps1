function Get-PerfilActivo {
    $perfilTxt = "$PSScriptRoot\..\..\perfil.txt"
    if (Test-Path $perfilTxt) {
        return (Get-Content $perfilTxt).Trim()
    }
    return "Normal"
}

function Set-Perfil {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Nombre
    )

    try {
        $clienteBase = "$PSScriptRoot\..\.."
        $presetsBase = "$PSScriptRoot\..\..\presets_graficos\$Nombre"
        $perfilTxt = "$PSScriptRoot\..\..\perfil.txt"

        $targets = @(
            @{ Src = "$presetsBase\embeddium-options.json"; Dest = "$clienteBase\config\embeddium-options.json" },
            @{ Src = "$presetsBase\oculus.properties"; Dest = "$clienteBase\config\oculus.properties" },
            @{ Src = "$presetsBase\options.txt"; Dest = "$clienteBase\options.txt" }
        )

        foreach ($t in $targets) {
            if (-not (Test-Path $t.Src)) {
                Write-Log -Mensaje "No se encontro plantilla de perfil: $($t.Src)" -Nivel WARN
                return $false
            }
            if (Test-Path $t.Dest) {
                Backup-Antes -Ruta $t.Dest
            } else {
                $destDir = Split-Path $t.Dest
                if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
            }
            Copy-Item -Path $t.Src -Destination $t.Dest -Force
        }

        if (Test-Path $perfilTxt) {
            Backup-Antes -Ruta $perfilTxt
        }
        Set-Content -Path $perfilTxt -Value $Nombre -Force
        Write-Log -Mensaje "Perfil establecido a: $Nombre" -Nivel INFO
        return $true
    } catch {
        Write-Log -Mensaje "Error al establecer perfil $Nombre : $($_.Exception.Message)" -Nivel ERROR
        return $false
    }
}
