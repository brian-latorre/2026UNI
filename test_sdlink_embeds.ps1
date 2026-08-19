$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$playerName = "Notch"
$playerUUID = "069a79f4-44e9-4726-a5be-fca90e38aaf5" # Notch's UUID for reliable head fetching

# ==========================================
# OPCIÓN 1: Sin Emojis (Minimalista / Limpio)
# ==========================================
$embed1 = @{
    title = "Conexion de Jugador"
    description = "**$playerName** ha entrado al servidor."
    color = 65280 # Verde
    author = @{
        name = "Informacion del Servidor"
        icon_url = "https://minotar.net/helm/$playerUUID/64.png"
    }
    thumbnail = @{
        url = "https://mc-heads.net/head/$playerUUID"
    }
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$payload1 = @{
    content = "Opcion 1 (Sin Emojis):"
    embeds = @($embed1)
}

$json1 = $payload1 | ConvertTo-Json -Depth 5
$temp1 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test1.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp1, $json1, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp1" $webhookUrl
Remove-Item -Path $temp1 -Force

Start-Sleep -Seconds 2

# ==========================================
# OPCIÓN 2: Con Emojis
# ==========================================
$embed2 = @{
    title = "[char]::ConvertFromUtf32(0x1F44B) ¡Un jugador se ha conectado!"
    description = "**$playerName** ha entrado al servidor. ¡A jugar!"
    color = 65280 # Verde
    author = @{
        name = "Informacion del Servidor"
        icon_url = "https://minotar.net/helm/$playerUUID/64.png"
    }
    thumbnail = @{
        url = "https://mc-heads.net/head/$playerUUID"
    }
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

# Fix encoding dynamically for emoji
$embed2.title = $embed2.title.Replace("[char]::ConvertFromUtf32(0x1F44B)", ([char]::ConvertFromUtf32(0x1F44B)))

$payload2 = @{
    content = "Opcion 2 (Con Emojis):"
    embeds = @($embed2)
}

$json2 = $payload2 | ConvertTo-Json -Depth 5
$temp2 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test2.json")
[System.IO.File]::WriteAllText($temp2, $json2, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp2" $webhookUrl
Remove-Item -Path $temp2 -Force

Write-Host "Pruebas enviadas."
