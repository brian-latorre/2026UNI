param (
    [Parameter(Mandatory=$true)]
    [string]$mcDir
)

# Discord Webhook URL (Proporcionada por el usuario)
$webhookUrl = "https://discord.com/api/webhooks/1530297589419737122/b2KDI3FLDwff5l1gZVH91evpwLyhX2ORRiar8vNJNO0J26ITrd4OLnw_2VS2x4Y9kBnR"

# Rutas
$crashDir = Join-Path -Path $mcDir -ChildPath "crash-reports"
$trackingFile = Join-Path -Path $mcDir -ChildPath ".last_sent_crash.txt"

# Si no hay carpeta de crashes, no hay nada que hacer
if (-not (Test-Path -Path $crashDir)) {
    exit 0
}

# Obtener el crash report más reciente
$latestCrash = Get-ChildItem -Path $crashDir -Filter "crash-*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($null -eq $latestCrash) {
    exit 0
}

# Verificar si ya lo enviamos
$lastSent = ""
if (Test-Path -Path $trackingFile) {
    $lastSent = (Get-Content -Path $trackingFile -Raw).Trim()
}

if ($latestCrash.Name -eq $lastSent) {
    # Ya se envió este crash report
    exit 0
}

# Intentar enviarlo directamente como archivo adjunto a Discord usando curl.exe (nativo en Windows 10+)
$curlPath = "C:\Windows\System32\curl.exe"

if (Test-Path -Path $curlPath) {
    # JSON payload
    $json = "{ `"content`": `"🚨 **¡Nuevo Crash Report Detectado!** <@351472135606108175>`n**Archivo:** $($latestCrash.Name)`" }"
    
    # Argumentos para curl.exe
    $args = @(
        "-F", "payload_json=$json",
        "-F", "file1=@$($latestCrash.FullName)",
        $webhookUrl
    )
    
    # Ejecutar curl
    $process = Start-Process -FilePath $curlPath -ArgumentList $args -NoNewWindow -Wait -PassThru
    
    if ($process.ExitCode -eq 0) {
        # Registrar que ya se envió exitosamente
        $latestCrash.Name | Out-File -FilePath $trackingFile -Encoding UTF8
        exit 0
    }
}

# Fallback: Si curl falla o no existe, enviamos las primeras líneas directamente a Discord en texto
$logContent = Get-Content -Path $latestCrash.FullName -Raw
$truncatedLog = $logContent
if ($logContent.Length -gt 1500) {
    $truncatedLog = $logContent.Substring(0, 1500) + "... [TRUNCADO]"
}

$discordPayload = @{
    content = "🚨 **¡Nuevo Crash Report Detectado!** <@351472135606108175> (Enviado como texto)`n**Archivo:** $($latestCrash.Name)`n" + '```text' + "`n$truncatedLog`n" + '```'
} | ConvertTo-Json -Depth 3

try {
    Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "application/json" -Body $discordPayload
    $latestCrash.Name | Out-File -FilePath $trackingFile -Encoding UTF8
} catch {
    # Si esto falla, no podemos hacer más nada
}
