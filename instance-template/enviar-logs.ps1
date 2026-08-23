param (
    [Parameter(Mandatory=$true)]
    [string]$mcDir,
    [switch]$startup,
    [switch]$watchdog,
    [switch]$postexit
)

# --- 1. CONFIGURACIÓN, CONSTANTES Y PROXY ---
# [SEGURIDAD]: Ahora enviamos al Proxy en Cloudflare para ocultar el Webhook de Discord
$apiEndpoint = "https://2026uni-telemetry.brianjairlatorre.workers.dev" # REEMPLAZAR CON URL DE WORKER. (Si falla, se envía pero el proxy gestiona el POST a Discord).
# Si aún no tienes el proxy listo, usa el webhook de discord como fallback bajo tu propio riesgo, pero la meta es el proxy.
$webhookUrl = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUzMDMxNzg3MjAyOTYzNDU5MS8zZFpqcEo0QlFHamN3bFhlQ1E3TU4zZHhwblB3YjFhblI3UzVQMzdvWnY1cGNHeXZOWHRUWnA2QktodXNxMVpXSF9Caw=="
$targetUrl = $apiEndpoint
$serverHost = "wriggly-jm.gl.joinmc.link"

$e_Usuario = [char]::ConvertFromUtf32(0x1F464)
$e_Tiempo  = [char]::ConvertFromUtf32(0x23F3)
$e_Juego   = [char]::ConvertFromUtf32(0x1F4C8)
$e_Inicio  = [char]::ConvertFromUtf32(0x25B6) + [char]::ConvertFromUtf32(0xFE0F)
$e_Cierre  = [char]::ConvertFromUtf32(0x23F9) + [char]::ConvertFromUtf32(0xFE0F)
$e_Motivo  = [char]::ConvertFromUtf32(0x1F4A5)
$e_Mods    = [char]::ConvertFromUtf32(0x1F50D)
$e_RAM     = [char]::ConvertFromUtf32(0x1F4BE)
$e_Net     = [char]::ConvertFromUtf32(0x1F310)
$phantom   = "$([char]0x200B)" 

$e_Check   = [char]::ConvertFromUtf32(0x2705)
$e_Lupa    = [char]::ConvertFromUtf32(0x1F50E)
$e_Stats   = [char]::ConvertFromUtf32(0x1F4CA)
$e_Rojo    = [char]::ConvertFromUtf32(0x1F534)
$e_Verde   = [char]::ConvertFromUtf32(0x1F7E2)
$crashDir       = Join-Path -Path $mcDir -ChildPath "crash-reports"
$logsDir        = Join-Path -Path $mcDir -ChildPath "logs"
$latestLog      = Join-Path -Path $logsDir -ChildPath "latest.log"
$debugLog       = Join-Path -Path $logsDir -ChildPath "debug.log"
$lockFile       = Join-Path -Path $mcDir -ChildPath ".session_lock"
$sentJsonFile   = Join-Path -Path $mcDir -ChildPath ".sent_reports.json"
$playtimeFile   = Join-Path -Path $mcDir -ChildPath ".playtime_tracker.json"
$queueDir       = Join-Path -Path $mcDir -ChildPath ".log_queue"
$telemetryFlag  = Join-Path -Path $mcDir -ChildPath ".no_telemetry"

$curlPath = "C:\Windows\System32\curl.exe"

# --- 2. VALIDACIONES BASE ---
if (Test-Path $telemetryFlag) { exit 0 } # Opt-out check
if (-not (Test-Path $curlPath)) { exit 0 }

# --- 3. FUNCIONES UTILITARIAS ---

function Get-FileSha256([string]$filePath) {
    if (-not (Test-Path $filePath)) { return "" }
    try {
        $stream = [System.IO.File]::OpenRead($filePath)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha.ComputeHash($stream)
        $stream.Close()
        return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToLower()
    } catch { return "" }
}

function Get-SentTracker {
    if (Test-Path $sentJsonFile) {
        try {
            $content = Get-Content -Path $sentJsonFile -Raw -ErrorAction SilentlyContinue
            if ($content) { return $content | ConvertFrom-Json }
        } catch {}
    }
    return [PSCustomObject]@{ sent_hashes = @(); sent_sessions = @() }
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
            if ($content) { return $content | ConvertFrom-Json }
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

function Format-Playtime([double]$mins) {
    $d = [math]::Floor($mins / 1440)
    $h = [math]::Floor(($mins % 1440) / 60)
    $m = [math]::Floor($mins % 60)
    $p = @()
    if ($d -gt 0) { $p += "$d d" }
    if ($h -gt 0) { $p += "$h h" }
    if ($m -gt 0) { $p += "$m min" }
    if ($p.Count -eq 0) { $p += "< 1 min" }
    return $p -join " "
}

function Sanitize-Text([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return "" }
    $text = $text -replace '`', "'"
    $text = $text -replace '(?i)[a-z]:\\Users\\[^\\]+', '%USERPROFILE%'
    $text = $text -replace '(?i)accessToken\s*[:=]\s*[^\s,]+', 'accessToken=[REDACTED]'
    $text = $text -replace '(?i)session\s*[:=]\s*[^\s,]+', 'session=[REDACTED]'
    return $text
}

function Send-Webhook([string]$jsonPayloadPath, [array]$attachments, [string]$tempDir) {
    $argsList = @("--connect-timeout", "10", "--max-time", "120", "-s", "-S", "-w", "\nHTTP_CODE:%{http_code}", "-F", "payload_json=<$jsonPayloadPath")
    
    foreach ($att in $attachments) {
        if ($att -and (Test-Path $att.Path)) {
            $argsList += "-F"
            $argsList += "$($att.FormName)=@$($att.Path)"
        }
    }
    $argsList += $targetUrl

    try {
        $outLog = Join-Path $tempDir "curl_out.log"
        $errLog = Join-Path $tempDir "curl_err.log"
        $proc = Start-Process -FilePath $curlPath -ArgumentList $argsList -WindowStyle Hidden -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog
        $finished = $proc.WaitForExit(125000)
        
        if (-not $finished) {
            try { $proc.Kill() } catch {}
            return $false
        }
        
        $httpCode = 0
        if (Test-Path $outLog) {
            $outContent = Get-Content $outLog -Raw
            if ($outContent -match "HTTP_CODE:(\d+)") { $httpCode = [int]$matches[1] }
        }
        
        if ($httpCode -eq 200 -or $httpCode -eq 204 -or ($httpCode -eq 0 -and $proc.ExitCode -eq 0)) { return $true } else { return $false }
    } catch { return $false }
}

function Get-HardwareMetrics {
    param([double]$MinFreeRAM = $null)
    $ramTotal = 0; $ramFree = 0; $diskFree = 0; $diskTotal = 0; $gpuName = "Desconocida"; $osName = "Desconocido"
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $osName = $os.Caption
            $ramTotal = [math]::Round($os.TotalVisibleMemorySize / 1024, 1) # MB
            if ($null -ne $MinFreeRAM -and $MinFreeRAM -gt 0) {
                $ramFree = $MinFreeRAM
            } else {
                $ramFree = [math]::Round($os.FreePhysicalMemory / 1024, 1) # MB
            }
        }
        $drive = [System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($mcDir))
        $diskFree = [math]::Round($drive.AvailableFreeSpace / 1GB, 1) # GB
        $diskTotal = [math]::Round($drive.TotalSize / 1GB, 1) # GB
        
        $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        if ($gpus) {
            $gpuNames = @()
            foreach ($gpu in $gpus) {
                $vram = ""
                if ($gpu.AdapterRAM) { $vram = " (" + [math]::Round($gpu.AdapterRAM / 1GB, 1) + " GB VRAM)" }
                $gpuNames += $gpu.Caption + $vram
            }
            $gpuName = $gpuNames -join " | "
        }
    } catch {}
    
    $ramAssigned = "No Definida"
    try {
        $instanceDir = Split-Path $mcDir
        $instanceCfgPath = Join-Path $instanceDir "instance.cfg"
        $ramMB = $null

        if (Test-Path $instanceCfgPath) {
            $cfg = Get-Content $instanceCfgPath -Raw
            if ($cfg -match "OverrideMemory=true" -and $cfg -match "MaxMemAlloc=(\d+)") {
                $ramMB = [int]$matches[1]
            } else {
                $launcherDir = Split-Path (Split-Path $instanceDir)
                $globalCfgPaths = @(
                    (Join-Path $launcherDir "elyprismlauncher.cfg"),
                    (Join-Path $launcherDir "prismlauncher.cfg"),
                    (Join-Path $launcherDir "pineconemc.cfg")
                )
                foreach ($path in $globalCfgPaths) {
                    if (Test-Path $path) {
                        $gCfg = Get-Content $path -Raw
                        if ($gCfg -match "MaxMemAlloc=(\d+)") {
                            $ramMB = [int]$matches[1]
                        }
                        break
                    }
                }
            }
        }
        if ($ramMB) {
            if ($ramMB -ge 1024) { $ramAssigned = "$([math]::Round($ramMB / 1024, 1)) GB" }
            else { $ramAssigned = "$ramMB MB" }
        }
    } catch {}
    
    return @{ RAMTotal = $ramTotal; RAMFree = $ramFree; RAMAssigned = $ramAssigned; DiskFree = $diskFree; DiskTotal = $diskTotal; GPU = $gpuName; OS = $osName }
}

function Get-Ping {
    try {
        $ping = Test-NetConnection -ComputerName $serverHost -ErrorAction SilentlyContinue
        if ($ping.PingSucceeded) { 
            return "Online ($($ping.PingReplyDetails.RoundtripTime) ms)" 
        } else { 
            return "Timeout (0 ms)" 
        }
    } catch { return "Error" }
}

function Get-BootTime {
    if (-not (Test-Path $latestLog)) { return "N/A" }
    try {
        $firstLine = (Get-Content $latestLog -TotalCount 1)
        if ($firstLine -match "\[(.*?)\]") {
            $startBoot = [datetime]::ParseExact($matches[1], "ddMMMyyyy HH:mm:ss.fff", [cultureinfo]::InvariantCulture)
            
            # Buscamos cuando inicia el SoundEngine, que ocurre exactamente cuando el juego termina de cargar el menú principal.
            $soundLine = Select-String -Path $latestLog -Pattern "Sound engine started" -List -ErrorAction SilentlyContinue
            if ($soundLine) {
                if ($soundLine.Line -match "\[(.*?)\]") {
                    $endBoot = [datetime]::ParseExact($matches[1], "ddMMMyyyy HH:mm:ss.fff", [cultureinfo]::InvariantCulture)
                    $totalSecs = ($endBoot - $startBoot).TotalSeconds
                    if ($totalSecs -ge 60) {
                        $mins = [math]::Floor($totalSecs / 60)
                        $secs = [math]::Round($totalSecs % 60, 0)
                        return "$mins min $secs s"
                    } else {
                        return "$([math]::Round($totalSecs, 1)) Segundos"
                    }
                }
            }
        }
    } catch {}
    return "N/A"
}

function Get-GameGPU {
    if (-not (Test-Path $latestLog)) { return "Desconocida" }
    try {
        $glLine = Select-String -Path $latestLog -Pattern "GL info: (.*)" -List -ErrorAction SilentlyContinue
        if ($glLine) {
            return $glLine.Matches[0].Groups[1].Value
        }
    } catch {}
    return "No Detectada (Uso Remoto/Headless)"
}

# --- 4. REDUNDANCIAS Y FILE LOCKING ---

$sessionInfo = $null
if (Test-Path $lockFile) {
    try {
        $lockRaw = Get-Content -Path $lockFile -Raw -ErrorAction SilentlyContinue
        if ($lockRaw) { $sessionInfo = $lockRaw | ConvertFrom-Json }
    } catch {}
}

if ($postexit) {
    # Evitamos duplicidad: Si existe el lock y el WatchdogPID aún vive, no hacemos nada y dejamos que el watchdog lo haga.
    # Si el WatchdogPID murió, entonces el post-exit toma el control.
    if ($sessionInfo -and $sessionInfo.WatchdogPID) {
        $wdProc = Get-Process -Id $sessionInfo.WatchdogPID -ErrorAction SilentlyContinue
        if ($wdProc) { exit 0 } # El Watchdog está vivo, abortamos post-exit.
    }
}

if ($startup) {
    # Verificador de APAGONES y Hard-Crashes.
    # Si arrancamos el launcher, hay lock y el WatchdogPID no corre = hubo apagón/kill.
    if ($sessionInfo) {
        $isOrphan = $true
        if ($sessionInfo.WatchdogPID) {
            $wdProc = Get-Process -Id $sessionInfo.WatchdogPID -ErrorAction SilentlyContinue
            if ($wdProc) { $isOrphan = $false }
        }
        if ($isOrphan) {
            # ¡Se apagó o murió el watchdog! Procesar log anterior antes de arrancar.
            # (El código de envío está abajo, así que simplemente continuará como si fuera un crasheo normal).
        } else {
            # Si curiosamente sigue vivo, no hacemos nada en startup
            exit 0
        }
    } else {
        # Inicio normal limpio, no hay apagon.
        exit 0
    }
}

if ($watchdog) {
    # Escribimos el Lock
    $username = "Desconocido"
    # Esperamos 10s para que Java inicie y podamos leer su PID
    Start-Sleep -Seconds 10
    $javaProc = Get-CimInstance Win32_Process -Filter "Name='javaw.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match "2026UNI" -or $_.CommandLine -match "PineconeMC" }
    # Intentar leer usuario del latest.log
    if (Test-Path $latestLog) {
        $matchInfo = Select-String -Path $latestLog -Pattern "Setting user:\s+([a-zA-Z0-9_]+)" -List -ErrorAction SilentlyContinue
        if ($matchInfo) { $username = $matchInfo.Matches[0].Groups[1].Value }
    }

    $newLockObj = @{
        SessionId = [guid]::NewGuid().ToString()
        StartTimeTicks = [datetime]::UtcNow.Ticks
        Username  = $username
        WatchdogPID = $PID
        MinFreeRAM = $null
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($lockFile, ($newLockObj | ConvertTo-Json), $utf8NoBom)

    # LOOP DE WATCHDOG (Cada 15 segundos verificamos si Java sigue vivo)
    while ($true) {
        Start-Sleep -Seconds 15
        
        # Monitoreo de RAM en tiempo real durante la partida
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os) {
                $currFree = [math]::Round($os.FreePhysicalMemory / 1024, 1)
                if ($null -eq $newLockObj.MinFreeRAM -or $currFree -lt $newLockObj.MinFreeRAM) {
                    $newLockObj.MinFreeRAM = $currFree
                    [System.IO.File]::WriteAllText($lockFile, ($newLockObj | ConvertTo-Json -Depth 2), $utf8NoBom)
                }
            }
        } catch {}

        if ($javaProc) {
            $procCheck = Get-Process -Id $javaProc.ProcessId -ErrorAction SilentlyContinue
            if (-not $procCheck) { break } # Se cerró Java
        } else {
            # Fallback si no pudimos enganchar el PID al inicio: chequear latest.log o procesos generales
            $anyJava = Get-WmiObject Win32_Process -Filter "Name='javaw.exe' AND CommandLine LIKE '%$([regex]::Escape($mcDir))%'" -ErrorAction SilentlyContinue
            if (-not $anyJava) { break } # Ya no hay Java de esta instancia
        }
    }
    
    # Releemos sessionInfo para continuar con el flujo normal de envío
    $lockRaw = Get-Content -Path $lockFile -Raw -ErrorAction SilentlyContinue
    if ($lockRaw) { $sessionInfo = $lockRaw | ConvertFrom-Json }
}

# --- 5. PREPARACIÓN DE DATOS A ENVIAR ---

$sessionStartTime = [datetime]::Now
if ($sessionInfo -and $sessionInfo.StartTimeTicks) { 
    $sessionStartTime = [datetime]::new($sessionInfo.StartTimeTicks, 'Utc').ToLocalTime() 
} else {
    $parsedBoot = $null
    if (Test-Path $latestLog) {
        $firstLine = (Get-Content $latestLog -TotalCount 1)
        if ($firstLine -match "\[(.*?)\]") {
            try { $parsedBoot = [datetime]::ParseExact($matches[1], "ddMMMyyyy HH:mm:ss.fff", [cultureinfo]::InvariantCulture) } catch {}
        }
    }
    if ($parsedBoot) { $sessionStartTime = $parsedBoot }
    elseif (Test-Path $latestLog) { $sessionStartTime = (Get-Item $latestLog).LastWriteTime }
}
$username = if ($sessionInfo -and $sessionInfo.Username) { $sessionInfo.Username } else { "Desconocido" }
if ($username -eq "Desconocido" -and (Test-Path $latestLog)) {
    $matchInfo = Select-String -Path $latestLog -Pattern "Setting user:\s+([a-zA-Z0-9_]+)" -List -ErrorAction SilentlyContinue
    if ($matchInfo) { $username = $matchInfo.Matches[0].Groups[1].Value }
}

$now = [datetime]::Now
$sessionSpan = $now - $sessionStartTime
$sessionMinutes = [math]::Max(0.1, [math]::Round($sessionSpan.TotalMinutes, 1))

$sessionPlaytimeStr = Format-Playtime -mins $sessionMinutes
$totalMinutes = Add-PlaytimeMinutes $sessionMinutes
$totalHoursStr = (Format-Playtime -mins $totalMinutes) + " totales"

$sentTracker = Get-SentTracker
$sentHashes = @($sentTracker.sent_hashes)
$latestLogHash = Get-FileSha256 $latestLog

# Prevenir duplicados (si el hash ya se mandó)
if ($latestLogHash -and ($sentHashes -contains $latestLogHash)) {
    if (Test-Path $lockFile) { Remove-Item -Path $lockFile -Force -ErrorAction SilentlyContinue }
    exit 0
}

# --- 6. ANÁLISIS DE CRASH Y LOGS ---
$isCrash = $false
$crashReason = "Cierre Normal"
$suspectMods = "N/A"
$crashFileToSend = $null
$crashFileHash = ""

# 6.1 Crash Report (Generado por Forge)
if (Test-Path $crashDir) {
    $candidates = Get-ChildItem -Path $crashDir -Filter "crash-*.txt" -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $sessionStartTime.AddSeconds(-5) } | Sort-Object LastWriteTime -Descending
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
    # 6.2 JVM Crash (hs_err_pid)
    $latestJvm = Get-ChildItem -Path $mcDir -Filter "hs_err_pid*.log" -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $sessionStartTime.AddSeconds(-5) } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestJvm) {
        $hash = Get-FileSha256 $latestJvm.FullName
        if ($hash -and ($sentHashes -notcontains $hash)) {
            $isCrash = $true
            $crashFileToSend = $latestJvm.FullName
            $crashFileHash = $hash
            $crashReason = "Colapso de JVM Java (Posible Falta de RAM o Gráficos)"
        }
    }
}

# 6.3 Verificación de latest.log (Hard Kills o Soft Crashes)
$exitCode = "0 (Normal)"
if (-not $isCrash -and (Test-Path $latestLog)) {
    $tailLines = Get-Content $latestLog -Tail 100 -ErrorAction SilentlyContinue
    $graceful = $false
    $hasFatalError = $false

    foreach ($line in $tailLines) {
        if ($line -match "Stopping!" -or $line -match "Stopping server" -or $line -match "Stopping worker threads") { $graceful = $true }
        if ($line -match "\[main/FATAL\]" -or $line -match "LoadingFailedException" -or $line -match "Exception in thread") { $hasFatalError = $true }
        if ($line -match "Process exited with code (-?\d+)") { 
            $code = $matches[1]
            if ($code -eq "-1") { $exitCode = "-1 (Crash Abrupto / Hardware Kill)" }
            elseif ($code -eq "255") { $exitCode = "255 (Crash de Mod/Exitcode genérico)" }
            elseif ($code -ne "0") { $exitCode = "$code (Fallo Desconocido)" }
        }
    }

    if ($hasFatalError) {
        $isCrash = $true
        $crashReason = "Fallo Fatal de Mods (Ver logs)"
        $crashFileHash = $latestLogHash
    } elseif (-not $graceful -and $sessionMinutes -gt 1.0 -and $startup) {
        # Si estamos arrancando (-startup) y el log anterior no terminó bien, fue un apagón
        $isCrash = $true
        $crashReason = "Apagón de PC o Cierre Forzado (-1)"
        $crashFileHash = $latestLogHash
    }
}

# --- 7. RECOLECCIÓN DE MÉTRICAS EXTRA (RAM, DISCO, PING, VER) ---
$minRamValue = if ($sessionInfo -and $null -ne $sessionInfo.MinFreeRAM) { $sessionInfo.MinFreeRAM } else { $null }
$hw = Get-HardwareMetrics -MinFreeRAM $minRamValue
$pingStatus = Get-Ping
$bootTime = Get-BootTime
$gameGpu = Get-GameGPU

$versionJsonFile = Join-Path $mcDir "config\2026UNI\version.json"
$verObj = "Versión Desconocida | Packwiz Sync Indefinido"

if (Test-Path $versionJsonFile) {
    try {
        $json = Get-Content $versionJsonFile -Raw | ConvertFrom-Json
        if ($null -ne $json.version) {
            $localVer = $json.version
            $verObj = "v$localVer | Packwiz JSON"
        } else {
            $verObj = "vLegacy | Error leyendo version en JSON"
        }
    } catch {
        $verObj = "vLegacy | Error parseando version.json"
    }
} else {
    $verObj = "vLegacy | Sin version.json local"
}

# --- 8. CONSTRUCCIÓN DEL PAYLOAD ---
$timestampIso = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$horaInicioStr = $sessionStartTime.ToString('dd/MM/yyyy HH:mm:ss')
$horaCierreStr = $now.ToString('dd/MM/yyyy HH:mm:ss')
$payloadObj = @{}

$crashReason = Sanitize-Text $crashReason
$suspectMods = Sanitize-Text $suspectMods
if ($crashReason.Length -gt 1000) { $crashReason = $crashReason.Substring(0, 990) + "..." }
if ($suspectMods.Length -gt 1000) { $suspectMods = $suspectMods.Substring(0, 990) + "..." }

# Emojis nuevos y Acentos para Embed Fields (A prueba de errores de codificación)
$e_Modpack   = [char]::ConvertFromUtf32(0x1F4E6)
$e_Exit      = [char]::ConvertFromUtf32(0x1F6AA)
$e_SO        = [char]::ConvertFromUtf32(0x1F4BB)
$e_GPU_PC    = [char]::ConvertFromUtf32(0x1F5A5) + [char]::ConvertFromUtf32(0xFE0F)
$e_GPU_Juego = [char]::ConvertFromUtf32(0x1F3AE)
$e_Disco     = [char]::ConvertFromUtf32(0x1F4BD)
$e_Boot      = [char]::ConvertFromUtf32(0x23F1) + [char]::ConvertFromUtf32(0xFE0F)
$e_Ping      = [char]::ConvertFromUtf32(0x1F4E1)
$a_ac = [char]0x00E1; $e_ac = [char]0x00E9; $i_ac = [char]0x00ED; $o_ac = [char]0x00F3; $u_ac = [char]0x00FA

$fields = @()

# 1. Usuario
$fields += @{ name = "$e_Usuario Usuario"; value = "**$username**"; inline = $false }

# 2. Tiempos
$fields += @{ name = "$e_Tiempo Tiempo de Sesi$($o_ac)n"; value = "$sessionPlaytimeStr"; inline = $false }


$fields += @{ name = "$e_Inicio Hora de Inicio"; value = "$horaInicioStr"; inline = $true }
$fields += @{ name = "$e_Cierre Hora de Cierre"; value = "$horaCierreStr"; inline = $true }
$fields += @{ name = $phantom; value = $phantom; inline = $true }

# 3. Datos Básicos
$fields += @{ name = "$e_Modpack Modpack"; value = "$verObj"; inline = $true }
$fields += @{ name = "$e_Exit Exit Code"; value = "$exitCode"; inline = $true }
$fields += @{ name = $phantom; value = $phantom; inline = $true }

# 4. Hardware y Sistema
$fields += @{ name = "$e_SO SO y Hardware"; value = "$($hw.OS)"; inline = $false }
$fields += @{ name = "$e_GPU_PC Gr$($a_ac)ficos (PC)"; value = "$($hw.GPU)"; inline = $false }
$fields += @{ name = "$e_GPU_Juego Gr$($a_ac)ficos (Juego)"; value = "$gameGpu"; inline = $false }
$fields += @{ name = "$e_RAM RAM (Triple)"; value = "Libre: $([math]::Round($hw.RAMFree/1024, 1)) GB | Asignada: $($hw.RAMAssigned) | Total: $([math]::Round($hw.RAMTotal/1024, 1)) GB"; inline = $false }

# 5. Disco, Boot, Ping
$fields += @{ name = "$e_Disco Disco"; value = "$([math]::Round($hw.DiskTotal - $hw.DiskFree, 1)) GB / $($hw.DiskTotal) GB ($($hw.DiskFree) GB Libres)"; inline = $true }
$fields += @{ name = "$e_Boot Boot Time"; value = "$bootTime"; inline = $true }
$fields += @{ name = "$e_Ping Ping al Servidor"; value = "$pingStatus"; inline = $true }

if ($isCrash) {
    $fields += @{ name = "$e_Motivo Motivo Crash"; value = "$crashReason"; inline = $false }
    if ($suspectMods -ne "N/A") {
        $fields += @{ name = "$e_Mods Mods Sospechosos"; value = "$suspectMods"; inline = $false }
    }
}

if ($isCrash) {
    $payloadObj.content = "<@351472135606108175> **[CRASH / INCIDENTE DETECTADO]**"
    $embed = @{
        title = "$e_Rojo [CRASH] Cierre Inesperado - $username"
        color = 16711680 # Rojo
        description = "El juego se ha cerrado inesperadamente."
        fields = $fields
        footer = @{ text = "Modpack 2026UNI - PineconeMC Launcher" }
        timestamp = $timestampIso
    }
} else {
    $embed = @{
        title = "$e_Verde [LOG] Sesion de Juego Finalizada"
        color = 65280 # Verde
        description = "El jugador ha cerrado el juego con normalidad."
        fields = $fields
        footer = @{ text = "Modpack 2026UNI - PineconeMC Launcher" }
        timestamp = $timestampIso
    }
}
$payloadObj.embeds = @($embed)

# --- 9. PREPARACIÓN DE ADJUNTOS CON COMPRESIÓN ZIP INTELIGENTE ---
$tempDir = Join-Path $env:TEMP "2026uni_report_$([guid]::NewGuid().ToString().Substring(0,8))"
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
$attachments = @()
$fileCounter = 1

if (Test-Path $latestLog) {
    $latestItem = Get-Item $latestLog
    if ($latestItem.Length -lt 5242880) {
        # Menos de 5 MB -> Envío crudo .log
        $destLog = Join-Path $tempDir "latest_$username.log"
        Copy-Item -Path $latestLog -Destination $destLog -Force
        $attachments += @{ FormName = "file$fileCounter"; Path = $destLog }
    } elseif ($latestItem.Length -lt 104857600) {
        # De 5 MB a 100 MB -> Compresión .zip inteligente
        $destZip = Join-Path $tempDir "latest_$username.zip"
        Compress-Archive -Path $latestLog -DestinationPath $destZip -Force
        # Validar que el ZIP sea menor a 25MB (limite discord)
        $zipItem = Get-Item $destZip
        if ($zipItem.Length -lt 26214400) {
            $attachments += @{ FormName = "file$fileCounter"; Path = $destZip }
        }
    }
    $fileCounter++
}

if ($isCrash -and $crashFileToSend -and (Test-Path $crashFileToSend)) {
    $crashItem = Get-Item $crashFileToSend
    if ($crashItem.Length -lt 5242880) {
        $destCrash = Join-Path $tempDir $crashItem.Name
        Copy-Item -Path $crashFileToSend -Destination $destCrash -Force
        $attachments += @{ FormName = "file$fileCounter"; Path = $destCrash }
        $fileCounter++
    }
}

if ($isCrash -and (Test-Path $debugLog)) {
    $debugItem = Get-Item $debugLog
    if ($debugItem.Length -lt 5242880) {
        $destDebug = Join-Path $tempDir "debug_$username.log"
        Copy-Item -Path $debugLog -Destination $destDebug -Force
        $attachments += @{ FormName = "file$fileCounter"; Path = $destDebug }
        $fileCounter++
    } elseif ($debugItem.Length -lt 104857600) {
        $destZip = Join-Path $tempDir "debug_$username.zip"
        Compress-Archive -Path $debugLog -DestinationPath $destZip -Force
        $zipItem = Get-Item $destZip
        if ($zipItem.Length -lt 26214400) {
            $attachments += @{ FormName = "file$fileCounter"; Path = $destZip }
            $fileCounter++
        }
    }
}

$jsonPayloadPath = Join-Path $tempDir "payload.json"
$jsonString = $payloadObj | ConvertTo-Json -Depth 5
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($jsonPayloadPath, $jsonString, $utf8NoBom)

# --- 10. ENVÍO Y LIMPIEZA ---
$sentOk = Send-Webhook -jsonPayloadPath $jsonPayloadPath -attachments $attachments -tempDir $tempDir

if ($sentOk) {
    $hashToSave = if ($crashFileHash) { $crashFileHash } else { $latestLogHash }
    if ($hashToSave -and ($sentHashes -notcontains $hashToSave)) {
        $sentTracker.sent_hashes += $hashToSave
        if ($sentTracker.sent_hashes.Count -gt 50) { $sentTracker.sent_hashes = $sentTracker.sent_hashes[-50..-1] }
        Save-SentTracker $sentTracker
    }
}

if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path $lockFile) { Remove-Item -Path $lockFile -Force -ErrorAction SilentlyContinue }

exit 0
