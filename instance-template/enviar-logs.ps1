param (
    [Parameter(Mandatory=$true)]
    [string]$mcDir,
    [switch]$startup
)

# Webhook ofuscado
$encWebhook = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUzMDMxNzg3MjAyOTYzNDU5MS8zZFpqcEo0QlFHamN3bFhlQ1E3TU4zZHhwblB3YjFhblI3UzVQMzdvWnY1cGNHeXZOWHRUWnA2QktodXNxMVpXSF9Caw=="
$webhookUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encWebhook))

$crashDir = Join-Path -Path $mcDir -ChildPath "crash-reports"
$logsDir = Join-Path -Path $mcDir -ChildPath "logs"
$latestLog = Join-Path -Path $logsDir -ChildPath "latest.log"
$trackingFile = Join-Path -Path $mcDir -ChildPath ".last_sent_crash.txt"
$lockFile = Join-Path -Path $mcDir -ChildPath ".session_lock"

$curlPath = "C:\Windows\System32\curl.exe"
if (-not (Test-Path $curlPath)) { exit 0 }

# 1. Obtener usuario de la sesión
$username = "Desconocido"
if (Test-Path $latestLog) {
    $userMatch = Select-String -Path $latestLog -Pattern "Setting user: ([\w_]+)" | Select-Object -First 1
    if ($userMatch) {
        $username = $userMatch.Matches[0].Groups[1].Value
    }
}

# 2. Extraer Tiempo de Juego (basado en la duración del latest.log)
$playtimeStr = "Desconocida"
if (Test-Path $latestLog) {
    $logItem = Get-Item $latestLog
    $playtimeSpan = $logItem.LastWriteTime - $logItem.CreationTime
    if ($playtimeSpan.TotalMinutes -lt 60) {
        $playtimeStr = "$([math]::Round($playtimeSpan.TotalMinutes, 1)) minutos"
    } else {
        $playtimeStr = "$([math]::Round($playtimeSpan.TotalHours, 1)) horas"
    }
}

# 3. Detectar estado de crasheo
$isCrash = $false
$crashReason = "Desconocida"
$suspectMods = "Ninguno detectado"
$crashFileToSend = $null

$lastSent = ""
if (Test-Path -Path $trackingFile) {
    $lastSent = (Get-Content -Path $trackingFile -Raw).Trim()
}

# Buscar el archivo de crash más reciente
$latestCrash = $null
if (Test-Path -Path $crashDir) {
    $latestCrash = Get-ChildItem -Path $crashDir -Filter "crash-*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# Buscar un JVM Crash dump (hs_err_pid)
$latestJvmCrash = Get-ChildItem -Path $mcDir -Filter "hs_err_pid*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Evaluación en orden de prioridad:
if ($latestCrash -and $latestCrash.Name -ne $lastSent) {
    # CRASH REPORT NORMAL (Minecraft detectó el error y lo guardó)
    $isCrash = $true
    $crashFileToSend = $latestCrash.FullName
    $fileIdToTrack = $latestCrash.Name
    try {
        $crashContent = Get-Content -Path $latestCrash.FullName -Raw -ErrorAction SilentlyContinue
        if ($crashContent -match "Description: (.+)") { $crashReason = $matches[1].Trim() }
        if ($crashContent -match "Suspected Mods:\s*(.+)") { $suspectMods = $matches[1].Trim() }
    } catch {}

} elseif ($latestJvmCrash -and $latestJvmCrash.Name -ne $lastSent) {
    # CRASH DE JAVA O MEMORIA (Sin crash-reports)
    $isCrash = $true
    $crashFileToSend = $latestJvmCrash.FullName
    $fileIdToTrack = $latestJvmCrash.Name
    $crashReason = "Colapso del sistema Java (Falta de Memoria o Driver)"

} elseif (Test-Path $latestLog) {
    # NO HAY ARCHIVO. Verificar de forma heurística leyendo el latest.log
    $logLastWrite = (Get-Item $latestLog).LastWriteTime.Ticks
    $abruptId = "abrupt_exit_$logLastWrite"

    if ($startup) {
        # Si estamos iniciando el juego, y existe un lock file de la sesión anterior,
        # significa que el juego se cerró de forma violenta sin pasar por el script de PostExit.
        if ((Test-Path $lockFile) -and ($abruptId -ne $lastSent)) {
            $isCrash = $true
            $fileIdToTrack = $abruptId
            $crashReason = "Cierre Violento (Detectado en el siguiente inicio. Ej: Se fue la luz)"
        }
    } else {
        # Estamos en PostExit. Revisamos las últimas 30 líneas del log.
        if ($abruptId -ne $lastSent) {
            $tailLines = Get-Content $latestLog -Tail 30 -ErrorAction SilentlyContinue
            $graceful = $false
            foreach ($line in $tailLines) {
                if ($line -match "Stopping!" -or $line -match "Stopping server" -or $line -match "Stopping worker threads") {
                    $graceful = $true
                    break
                }
            }
            if (-not $graceful) {
                $isCrash = $true
                $fileIdToTrack = $abruptId
                $crashReason = "Cierre Abrupto (Juego forzado a cerrar sin generar archivo crash)"
            }
        }
    }
}

# 4. Lógica de control de flujo basada en Startup vs PostExit
if ($startup) {
    if (-not $isCrash) {
        # Sesión limpia de inicio. Creamos candado y salimos silenciosamente.
        New-Item -Path $lockFile -ItemType File -Force | Out-Null
        exit 0
    }
} else {
    # PostExit. Limpiamos el candado de sesión activa.
    if (Test-Path $lockFile) {
        Remove-Item -Path $lockFile -Force -ErrorAction SilentlyContinue
    }
    # Si no es crash, enviaremos el reporte normal de sesión finalizada.
}

# 5. Envío al Webhook de Discord
if (Test-Path $latestLog) {
    $tempLog = Join-Path $env:TEMP "latest_$username.log"
    Copy-Item -Path $latestLog -Destination $tempLog -Force

    $timestamp = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $payloadObj = @{}

    if ($isCrash) {
        # Evitar sobrepasar límite de Discord Embed
        if ($crashReason.Length -gt 1000) { $crashReason = $crashReason.Substring(0, 1000) + "..." }
        if ($suspectMods.Length -gt 1000) { $suspectMods = $suspectMods.Substring(0, 1000) + "..." }
        
        $embed = @{
            title = "[CRASH] Reporte de Crash de Minecraft"
            description = "Se ha detectado un cierre inesperado del juego."
            color = 16711680
            fields = @(
                @{ name = "Usuario"; value = "**$username**"; inline = $true },
                @{ name = "Tiempo Jugado"; value = "$playtimeStr"; inline = $true },
                @{ name = "Archivo Crash"; value = "**$(if ($crashFileToSend) { (Get-Item $crashFileToSend).Name } else { 'Ninguno generado' })**"; inline = $false },
                @{ name = "Motivo (aprox)"; value = "$crashReason"; inline = $false },
                @{ name = "Mods Sospechosos"; value = "$suspectMods"; inline = $false }
            )
            footer = @{ text = "Modpack 2026UNI - PineconeMC Launcher" }
            timestamp = $timestamp
        }
        $payloadObj.content = "<@351472135606108175> **CRASH DETECTADO**"
        $payloadObj.embeds = @($embed)
    } else {
        $embed = @{
            title = "[LOG] Sesion de Juego Finalizada"
            description = "El jugador ha cerrado el juego con normalidad."
            color = 65280
            fields = @(
                @{ name = "Usuario"; value = "**$username**"; inline = $true },
                @{ name = "Tiempo Jugado"; value = "$playtimeStr"; inline = $true }
            )
            footer = @{ text = "Modpack 2026UNI - PineconeMC Launcher" }
            timestamp = $timestamp
        }
        $payloadObj.embeds = @($embed)
    }
    
    $tempJson = Join-Path $env:TEMP "discord_payload.json"
    $jsonString = $payloadObj | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($tempJson, $jsonString, [System.Text.Encoding]::UTF8)
    
    $argsList = @("-F", "payload_json=<$tempJson")
    
    if ($isCrash -and $crashFileToSend) {
        $tempCrash = Join-Path $env:TEMP (Get-Item $crashFileToSend).Name
        Copy-Item -Path $crashFileToSend -Destination $tempCrash -Force
        $argsList += "-F", "file1=@$tempCrash", "-F", "file2=@$tempLog"
    } else {
        $argsList += "-F", "file1=@$tempLog"
    }
    
    $argsList += $webhookUrl
    
    $process = Start-Process -FilePath $curlPath -ArgumentList $argsList -NoNewWindow -Wait -PassThru
    
    # Limpieza
    if (Test-Path $tempLog) { Remove-Item $tempLog -Force }
    if (Test-Path $tempJson) { Remove-Item $tempJson -Force }
    
    if ($isCrash) {
        if ($crashFileToSend -and (Test-Path $tempCrash)) {
            Remove-Item $tempCrash -Force
        }
        # Si se envió con éxito, registramos este crash para no volver a enviarlo
        if ($process.ExitCode -eq 0 -and $fileIdToTrack) {
            $fileIdToTrack | Out-File -FilePath $trackingFile -Encoding UTF8
        }
        
        # En caso de que estemos en startup y enviamos un crash atrasado,
        # ahora sí creamos el lock para la sesión que está por iniciar.
        if ($startup) {
            New-Item -Path $lockFile -ItemType File -Force | Out-Null
        }
    }
}
