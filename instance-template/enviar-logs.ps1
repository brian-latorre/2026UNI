param (
    [Parameter(Mandatory=$true)]
    [string]$mcDir,
    [switch]$startup
)

# Configuración y Constantes
$encWebhook = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUzMDMxNzg3MjAyOTYzNDU5MS8zZFpqcEo0QlFHamN3bFhlQ1E3TU4zZHhwblB3YjFhblI3UzVQMzdvWnY1cGNHeXZOWHRUWnA2QktodXNxMVpXSF9Caw=="
$webhookUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encWebhook))

$crashDir       = Join-Path -Path $mcDir -ChildPath "crash-reports"
$logsDir        = Join-Path -Path $mcDir -ChildPath "logs"
$latestLog      = Join-Path -Path $logsDir -ChildPath "latest.log"
$debugLog       = Join-Path -Path $logsDir -ChildPath "debug.log"
$lockFile       = Join-Path -Path $mcDir -ChildPath ".session_lock"
$sentJsonFile   = Join-Path -Path $mcDir -ChildPath ".sent_reports.json"
$playtimeFile   = Join-Path -Path $mcDir -ChildPath ".playtime_tracker.json"
$queueDir       = Join-Path -Path $mcDir -ChildPath ".log_queue"

$curlPath = "C:\Windows\System32\curl.exe"
if (-not (Test-Path $curlPath)) { exit 0 }

# --- FUNCIONES DE UTILIDAD Y SEGUIMIENTO ---

function Get-FileSha256([string]$filePath) {
    if (-not (Test-Path $filePath)) { return "" }
    try {
        $stream = [System.IO.File]::OpenRead($filePath)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha.ComputeHash($stream)
        $stream.Close()
        return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToLower()
    } catch {
        return ""
    }
}

function Get-SentTracker {
    if (Test-Path $sentJsonFile) {
        try {
            $content = Get-Content -Path $sentJsonFile -Raw -ErrorAction SilentlyContinue
            if ($content) {
                return $content | ConvertFrom-Json
            }
        } catch {}
    }
    return [PSCustomObject]@{
        sent_hashes = @()
        sent_sessions = @()
    }
}

function Save-SentTracker($tracker) {
    try {
        $json = $tracker | ConvertTo-Json -Depth 5
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($sentJsonFile, $json, $utf8NoBom)
    } catch {}
}

function Get-PlaytimeTracker {
    if (Test-Path $playtimeFile) {
        try {
            $content = Get-Content -Path $playtimeFile -Raw -ErrorAction SilentlyContinue
            if ($content) {
                return $content | ConvertFrom-Json
            }
        } catch {}
    }
    return [PSCustomObject]@{ total_minutes = 0.0 }
}

function Add-PlaytimeMinutes([double]$minutes) {
    $tracker = Get-PlaytimeTracker
    $tracker.total_minutes = [math]::Round(($tracker.total_minutes + $minutes), 2)
    try {
        $json = $tracker | ConvertTo-Json -Depth 3
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($playtimeFile, $json, $utf8NoBom)
    } catch {}
    return $tracker.total_minutes
}

function Sanitize-Text([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return "" }
    # Ocultar rutas de usuario de Windows (Ej. C:\Users\Nombre...)
    $text = $text -replace '(?i)[a-z]:\\Users\\[^\\]+', '%USERPROFILE%'
    # Ocultar tokens de acceso o sesión
    $text = $text -replace '(?i)accessToken\s*[:=]\s*[^\s,]+', 'accessToken=[REDACTED]'
    $text = $text -replace '(?i)session\s*[:=]\s*[^\s,]+', 'session=[REDACTED]'
    return $text
}

function Send-DiscordWebhookPayload([string]$jsonPayloadPath, [array]$attachments) {
    $argsList = @("--connect-timeout", "10", "--max-time", "30", "-s", "-S", "-F", "payload_json=<$jsonPayloadPath")
    
    foreach ($att in $attachments) {
        if ($att -and (Test-Path $att.Path)) {
            $argsList += "-F"
            $argsList += "$($att.FormName)=@$($att.Path)"
        }
    }
    $argsList += $webhookUrl

    try {
        $proc = Start-Process -FilePath $curlPath -ArgumentList $argsList -NoNewWindow -PassThru
        $finished = $proc.WaitForExit(35000)
        if (-not $finished) {
            try { $proc.Kill() } catch {}
            return $false
        }
        return ($proc.ExitCode -eq 0)
    } catch {
        return $false
    }
}

function Sync-OfflineQueue {
    if (-not (Test-Path $queueDir)) { return }
    $pendingItems = Get-ChildItem -Path $queueDir -Directory -ErrorAction SilentlyContinue
    foreach ($item in $pendingItems) {
        $payloadFile = Join-Path $item.FullName "payload.json"
        if (Test-Path $payloadFile) {
            $attachments = @()
            $fileIdx = 1
            Get-ChildItem -Path $item.FullName -File | Where-Object { $_.Name -ne "payload.json" } | ForEach-Object {
                $attachments += @{ FormName = "file$fileIdx"; Path = $_.FullName }
                $fileIdx++
            }
            $success = Send-DiscordWebhookPayload -jsonPayloadPath $payloadFile -attachments $attachments
            if ($success) {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# --- 1. PROCESAR COLA PENDIENTE (SI EXISTE) ---
Sync-OfflineQueue

# --- 2. LEER METADATOS DE SESIÓN ACTIVE / PREVIA (.session_lock) ---
$sessionInfo = $null
$sessionStartTime = [datetime]::Now
$username = "Desconocido"

if (Test-Path $lockFile) {
    try {
        $lockRaw = Get-Content -Path $lockFile -Raw -ErrorAction SilentlyContinue
        if ($lockRaw) {
            $sessionInfo = $lockRaw | ConvertFrom-Json
            if ($sessionInfo.StartTime) {
                $sessionStartTime = [datetime]::Parse($sessionInfo.StartTime)
            }
            if ($sessionInfo.Username) {
                $username = $sessionInfo.Username
            }
        }
    } catch {}
}

# Fallback para nombre de usuario si no estaba en .session_lock
if ($username -eq "Desconocido" -and (Test-Path $latestLog)) {
    try {
        $firstLines = Get-Content -Path $latestLog -Head 200 -ErrorAction SilentlyContinue
        foreach ($line in $firstLines) {
            if ($line -match "Setting user: ([\w_]+)") {
                $username = $matches[1]
                break
            }
        }
    } catch {}
}

# --- 3. MANEJO DEL MODO -STARTUP ---
if ($startup) {
    if (-not $sessionInfo) {
        # Inicio limpio sin sesión colgada previa. Crear .session_lock para la nueva sesión y salir.
        $newLockObj = @{
            SessionId = [guid]::NewGuid().ToString()
            StartTime = [datetime]::Now.ToString("o")
            Username  = $username
        }
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($lockFile, ($newLockObj | ConvertTo-Json), $utf8NoBom)
        exit 0
    }
}

# --- 4. CÁLCULO DE TIEMPO DE JUEGO (SESIÓN Y ACUMULADO) ---
$now = [datetime]::Now
$sessionSpan = $now - $sessionStartTime
$sessionMinutes = [math]::Max(0.1, [math]::Round($sessionSpan.TotalMinutes, 1))

if ($sessionMinutes -lt 60) {
    $sessionPlaytimeStr = "$sessionMinutes minutos"
} else {
    $sessionPlaytimeStr = "$([math]::Round($sessionSpan.TotalHours, 1)) horas"
}

$totalMinutes = Add-PlaytimeMinutes $sessionMinutes
$totalHoursStr = "$([math]::Round(($totalMinutes / 60), 1)) horas totales"

# --- 5. EVALUACIÓN DE CRASH Y PREVENCIÓN DE DUPLICADOS ---
$sentTracker = Get-SentTracker
$sentHashes = @($sentTracker.sent_hashes)

$isCrash = $false
$crashReason = "Desconocida"
$suspectMods = "Ninguno detectado"
$crashFileToSend = $null
$crashFileHash = ""

# Prioridad 1: crash-*.txt reciente generado en la sesión actual
$latestCrash = $null
if (Test-Path $crashDir) {
    $candidates = Get-ChildItem -Path $crashDir -Filter "crash-*.txt" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $sessionStartTime.AddSeconds(-5) } |
        Sort-Object LastWriteTime -Descending

    foreach ($cand in $candidates) {
        $hash = Get-FileSha256 $cand.FullName
        if ($hash -and ($sentHashes -notcontains $hash)) {
            $latestCrash = $cand
            $crashFileHash = $hash
            break
        }
    }
}

if ($latestCrash) {
    $isCrash = $true
    $crashFileToSend = $latestCrash.FullName
    try {
        $crashContent = Get-Content -Path $latestCrash.FullName -Raw -ErrorAction SilentlyContinue
        if ($crashContent -match "Description: (.+)") { $crashReason = $matches[1].Trim() }
        if ($crashContent -match "Suspected Mods:\s*(.+)") { $suspectMods = $matches[1].Trim() }
    } catch {}
} else {
    # Prioridad 2: hs_err_pid*.log de JVM generado en esta sesión
    $latestJvm = Get-ChildItem -Path $mcDir -Filter "hs_err_pid*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $sessionStartTime.AddSeconds(-5) } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($latestJvm) {
        $hash = Get-FileSha256 $latestJvm.FullName
        if ($hash -and ($sentHashes -notcontains $hash)) {
            $isCrash = $true
            $crashFileToSend = $latestJvm.FullName
            $crashFileHash = $hash
            $crashReason = "Colapso de JVM Java / Falta de Memoria RAM"
        }
    }
}

# Prioridad 3: Verificación por lectura de latest.log (Cierre Abrupto o Boot Crash)
if (-not $isCrash -and (Test-Path $latestLog)) {
    $logHash = Get-FileSha256 $latestLog
    if ($logHash -and ($sentHashes -notcontains $logHash)) {
        $tailLines = Get-Content $latestLog -Tail 50 -ErrorAction SilentlyContinue
        $graceful = $false
        $hasFatalError = $false

        foreach ($line in $tailLines) {
            if ($line -match "Stopping!" -or $line -match "Stopping server" -or $line -match "Stopping worker threads") {
                $graceful = $true
            }
            if ($line -match "\[main/FATAL\]" -or $line -match "LoadingFailedException" -or $line -match "Exception in thread") {
                $hasFatalError = $true
            }
        }

        if ($hasFatalError) {
            $isCrash = $true
            $crashReason = "Fallo Fatal durante la carga de Mods / Inicio"
            $crashFileHash = $logHash
        } elseif (-not $graceful) {
            $isCrash = $true
            $crashReason = "Cierre Abrupto / Inesperado de la sesion"
            $crashFileHash = $logHash
        }
    }
}

# --- 6. CONSTRUCCIÓN DEL PAYLOAD DE DISCORD ---
$timestampIso = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$timeLocalStr = $now.ToString('dd/MM/yyyy HH:mm:ss')

$payloadObj = @{}

$crashReason = Sanitize-Text $crashReason
$suspectMods = Sanitize-Text $suspectMods

if ($crashReason.Length -gt 1000) { $crashReason = $crashReason.Substring(0, 1000) + "..." }
if ($suspectMods.Length -gt 1000) { $suspectMods = $suspectMods.Substring(0, 1000) + "..." }

if ($isCrash) {
    # Mención solo en crash
    $payloadObj.content = "<@351472135606108175> **[CRASH DETECTADO]**"
    $embed = @{
        title = "[CRASH] Reporte de Cierre Inesperado"
        description = "Se ha detectado una interrupcion o fallo en el juego."
        color = 16711680 # Rojo
        fields = @(
            @{ name = "Usuario"; value = "**$username**"; inline = $true },
            @{ name = "Tiempo de Sesion"; value = "$sessionPlaytimeStr"; inline = $true },
            @{ name = "Tiempo Total"; value = "$totalHoursStr"; inline = $true },
            @{ name = "Fecha y Hora (Local)"; value = "$timeLocalStr"; inline = $false },
            @{ name = "Motivo (aprox)"; value = "$crashReason"; inline = $false },
            @{ name = "Mods Sospechosos"; value = "$suspectMods"; inline = $false }
        )
        footer = @{ text = "Modpack 2026UNI - PineconeMC Launcher" }
        timestamp = $timestampIso
    }
    $payloadObj.embeds = @($embed)
} else {
    # Cierre normal sin mención
    $embed = @{
        title = "[LOG] Sesion de Juego Finalizada"
        description = "El jugador ha cerrado el juego con normalidad."
        color = 65280 # Verde
        fields = @(
            @{ name = "Usuario"; value = "**$username**"; inline = $true },
            @{ name = "Tiempo de Sesion"; value = "$sessionPlaytimeStr"; inline = $true },
            @{ name = "Tiempo Total"; value = "$totalHoursStr"; inline = $true },
            @{ name = "Fecha y Hora (Local)"; value = "$timeLocalStr"; inline = $false }
        )
        footer = @{ text = "Modpack 2026UNI - PineconeMC Launcher" }
        timestamp = $timestampIso
    }
    $payloadObj.embeds = @($embed)
}

# --- 7. PREPARAR ARCHIVOS ADJUNTOS ---
$tempDir = Join-Path $env:TEMP "2026uni_report_$([guid]::NewGuid().ToString().Substring(0,8))"
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

$attachments = @()
$fileCounter = 1

# Copiar latest.log
if (Test-Path $latestLog) {
    $destLog = Join-Path $tempDir "latest_$username.log"
    Copy-Item -Path $latestLog -Destination $destLog -Force
    $attachments += @{ FormName = "file$fileCounter"; Path = $destLog }
    $fileCounter++
}

# Copiar crash-report o hs_err_pid si aplica
if ($isCrash -and $crashFileToSend -and (Test-Path $crashFileToSend)) {
    $destCrash = Join-Path $tempDir (Get-Item $crashFileToSend).Name
    Copy-Item -Path $crashFileToSend -Destination $destCrash -Force
    $attachments += @{ FormName = "file$fileCounter"; Path = $destCrash }
    $fileCounter++
}

# Copiar debug.log si hay crash y existe (para ver errores de mixin/cargas)
if ($isCrash -and (Test-Path $debugLog)) {
    $debugItem = Get-Item $debugLog
    # Solo adjuntar si pesa menos de 20 MB para evitar exceder límite de Discord
    if ($debugItem.Length -lt 20971520) {
        $destDebug = Join-Path $tempDir "debug_$username.log"
        Copy-Item -Path $debugLog -Destination $destDebug -Force
        $attachments += @{ FormName = "file$fileCounter"; Path = $destDebug }
        $fileCounter++
    }
}

# Escrebir JSON Payload
$jsonPayloadPath = Join-Path $tempDir "payload.json"
$jsonString = $payloadObj | ConvertTo-Json -Depth 5
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($jsonPayloadPath, $jsonString, $utf8NoBom)

# --- 8. ENVÍO O ENCOLA MODO OFFLINE ---
$sentOk = Send-DiscordWebhookPayload -jsonPayloadPath $jsonPayloadPath -attachments $attachments

if ($sentOk) {
    # Guardar en tracker de hashes para evitar reenvíos
    if ($crashFileHash) {
        $sentTracker.sent_hashes += $crashFileHash
        Save-SentTracker $sentTracker
    }
} else {
    # Guardar en cola offline .log_queue/
    if (-not (Test-Path $queueDir)) { New-Item -Path $queueDir -ItemType Directory -Force | Out-Null }
    $queueSessionDir = Join-Path $queueDir "queue_$([guid]::NewGuid().ToString().Substring(0,8))"
    Copy-Item -Path $tempDir -Destination $queueSessionDir -Recurse -Force
}

# --- 9. LIMPIEZA ---
if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path $lockFile) { Remove-Item -Path $lockFile -Force -ErrorAction SilentlyContinue }

# Si estamos en -startup y habíamos procesado un crash pendiente, crear el .session_lock para la nueva sesión que arranca
if ($startup) {
    $newLockObj = @{
        SessionId = [guid]::NewGuid().ToString()
        StartTime = [datetime]::Now.ToString("o")
        Username  = $username
    }
    [System.IO.File]::WriteAllText($lockFile, ($newLockObj | ConvertTo-Json), $utf8NoBom)
}

exit 0
