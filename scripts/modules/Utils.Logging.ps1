<#
    Utils.Logging.ps1
    ═══════════════════════════════════════════════════════════════
    Módulo de utilidades del Configurador Gráfico 2026UNI.
    
    Responsabilidades:
      1. Validar que el runtime de WPF esté disponible (Windows Desktop Runtime).
      2. Logging estructurado a archivo con timestamp y nivel.
      3. Backup automático (.bak-{timestamp}) antes de cualquier sobrescritura.
    
    Este módulo se carga PRIMERO — antes que cualquier otro módulo o código XAML.
    Si Test-WPFRuntime falla, el script debe salir inmediatamente.
    ═══════════════════════════════════════════════════════════════
#>

function Test-WPFRuntime {
    <#
    .SYNOPSIS
        Verifica que los assemblies de WPF estén disponibles en este runtime de PowerShell.
    .DESCRIPTION
        PowerShell 7+ sobre Windows puede cargar WPF, pero SOLO si el Windows Desktop Runtime
        de .NET está instalado (no basta el runtime base de .NET). Si falta, Add-Type truena
        en silencio y el script cierra sin que el jugador vea nada — porque corre con
        -WindowStyle Hidden desde el .bat.
        
        Esta función se llama ANTES de cualquier código WPF. Si falla, el único canal de
        comunicación es un archivo de log (no podemos mostrar MessageBox porque WPF no cargó).
    .OUTPUTS
        [bool] $true si WPF cargó correctamente, $false si no.
    #>
    try {
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml -ErrorAction Stop
        return $true
    }
    catch {
        # No podemos usar Write-Log aquí porque depende de que el módulo ya esté cargado
        # y podría no haber fallado por una razón de log. Escribimos directo al disco.
        $logDir = Join-Path $PSScriptRoot "..\..\logs"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        $logFile = Join-Path $logDir "fatal.log"
        
        @(
            "[$(Get-Date -Format o)] FATAL: No se pudo cargar WPF (PresentationFramework)."
            "[$(Get-Date -Format o)] Causa probable: falta Windows Desktop Runtime."
            "[$(Get-Date -Format o)] Descarga: https://dotnet.microsoft.com/download/dotnet"
            "[$(Get-Date -Format o)] Detalle técnico: $($_.Exception.Message)"
            "---"
        ) | Out-File $logFile -Append -Encoding utf8
        
        return $false
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Escribe un mensaje estructurado al archivo de log del día.
    .DESCRIPTION
        Cada día genera un archivo separado (configurador-YYYY-MM-DD.log) en la carpeta
        logs/ del Configurador. El formato es:
            [timestamp] [NIVEL] Mensaje
        
        La carpeta logs/ se crea automáticamente si no existe.
        Este módulo NO versiona los logs en Git — están en .gitignore.
    .PARAMETER Mensaje
        Texto del mensaje a registrar.
    .PARAMETER Nivel
        Severidad: INFO (operación normal), WARN (algo inesperado pero no fatal),
        ERROR (fallo que se capturó y se manejó).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Mensaje,

        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Nivel = "INFO"
    )

    $logDir = Join-Path $PSScriptRoot "..\..\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $fecha    = Get-Date -Format "yyyy-MM-dd"
    $logFile  = Join-Path $logDir "configurador-$fecha.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    "[$timestamp] [$Nivel] $Mensaje" | Out-File $logFile -Append -Encoding utf8
}

function Backup-Antes {
    <#
    .SYNOPSIS
        Crea una copia de seguridad de un archivo antes de sobrescribirlo.
    .DESCRIPTION
        Copia el archivo a {ruta}.bak-{yyyyMMdd-HHmmss}. El timestamp en el nombre
        garantiza que nunca se pisa un backup previo — cada invocación genera un nombre
        único (resolución de 1 segundo).
        
        Si el archivo origen no existe, no es un error fatal: se loguea como WARN y
        se retorna $false. Esto permite que el código llamador decida si continuar
        (ej. "no había nada que respaldar, pero la operación puede proseguir").
    .PARAMETER Ruta
        Ruta completa al archivo que se va a respaldar.
    .OUTPUTS
        [bool] $true si el backup se creó exitosamente, $false si no.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Ruta
    )

    if (-not (Test-Path $Ruta)) {
        Write-Log -Mensaje "Backup-Antes: archivo no existe, nada que respaldar: $Ruta" -Nivel WARN
        return $false
    }

    try {
        $timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "$Ruta.bak-$timestamp"
        Copy-Item -Path $Ruta -Destination $backupPath -Force
        Write-Log -Mensaje "Backup creado: $backupPath" -Nivel INFO
        return $true
    }
    catch {
        Write-Log -Mensaje "Error al crear backup de '$Ruta': $($_.Exception.Message)" -Nivel ERROR
        return $false
    }
}
