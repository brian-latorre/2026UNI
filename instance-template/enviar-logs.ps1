param (
    [Parameter(Mandatory=$true)]
    [string]$mcDir
)

# Webhook ofuscado
$encWebhook = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUzMDMxNzg3MjAyOTYzNDU5MS8zZFpqcEo0QlFHamN3bFhlQ1E3TU4zZHhwblB3YjFhblI3UzVQMzdvWnY1cGNHeXZOWHRUWnA2QktodXNxMVpXSF9Caw=="
$webhookUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encWebhook))

$crashDir = Join-Path -Path $mcDir -ChildPath "crash-reports"
$logsDir = Join-Path -Path $mcDir -ChildPath "logs"
$latestLog = Join-Path -Path $logsDir -ChildPath "latest.log"
$trackingFile = Join-Path -Path $mcDir -ChildPath ".last_sent_crash.txt"

# 1. Obtener usuario (Fijo el bug de -Top 1 en PS 5.1)
$username = "Desconocido"
if (Test-Path $latestLog) {
    $userMatch = Select-String -Path $latestLog -Pattern "Setting user: ([\w_]+)" | Select-Object -First 1
    if ($userMatch) {
        $username = $userMatch.Matches[0].Groups[1].Value
    }
}

# 2. Crash Reports
$latestCrash = $null
if (Test-Path -Path $crashDir) {
    $latestCrash = Get-ChildItem -Path $crashDir -Filter "crash-*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$sendCrash = $false
if ($latestCrash) {
    $lastSent = ""
    if (Test-Path -Path $trackingFile) {
        $lastSent = (Get-Content -Path $trackingFile -Raw).Trim()
    }
    if ($latestCrash.Name -ne $lastSent) {
        $sendCrash = $true
    }
}

$curlPath = "C:\Windows\System32\curl.exe"
if (-not (Test-Path $curlPath)) {
    exit 0
}

# 3. Extraer Metadatos Extra
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

$crashReason = "No se pudo extraer automaticamente"
$suspectMods = "Ninguno detectado por Forge/Fabric"
if ($sendCrash -and ($latestCrash -ne $null)) {
    try {
        $crashContent = Get-Content -Path $latestCrash.FullName -Raw -ErrorAction SilentlyContinue
        if ($crashContent -match "Description: (.+)") {
            $crashReason = $matches[1].Trim()
        }
        if ($crashContent -match "Suspected Mods:\s*(.+)") {
            $suspectMods = $matches[1].Trim()
        }
    } catch {}
}

# 4. Enviar todo
if (Test-Path $latestLog) {
    $tempLog = Join-Path $env:TEMP "latest_$username.log"
    Copy-Item -Path $latestLog -Destination $tempLog -Force

    $timestamp = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $payloadObj = @{}

    if ($sendCrash) {
        $embed = @{
            title = "[CRASH] Reporte de Crash de Minecraft"
            description = "Se ha detectado un cierre inesperado del juego."
            color = 16711680
            fields = @(
                @{ name = "Usuario"; value = "**$username**"; inline = $true },
                @{ name = "Tiempo Jugado"; value = "$playtimeStr"; inline = $true },
                @{ name = "Archivo Crash"; value = "**$($latestCrash.Name)**"; inline = $false },
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
    
    if ($sendCrash) {
        $tempCrash = Join-Path $env:TEMP $latestCrash.Name
        Copy-Item -Path $latestCrash.FullName -Destination $tempCrash -Force
        $argsList += "-F", "file1=@$tempCrash", "-F", "file2=@$tempLog"
    } else {
        $argsList += "-F", "file1=@$tempLog"
    }
    
    $argsList += $webhookUrl
    
    $process = Start-Process -FilePath $curlPath -ArgumentList $argsList -NoNewWindow -Wait -PassThru
    
    if (Test-Path $tempLog) { Remove-Item $tempLog -Force }
    if (Test-Path $tempJson) { Remove-Item $tempJson -Force }
    
    if ($sendCrash -and (Test-Path $tempCrash)) {
        Remove-Item $tempCrash -Force
        if ($process.ExitCode -eq 0) {
            $latestCrash.Name | Out-File -FilePath $trackingFile -Encoding UTF8
        }
    }
}
