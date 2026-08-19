$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$serverName = "Minecraft Server"
$serverAvatar = "https://i.pinimg.com/1200x/88/8b/a9/888ba992b024f21cc4effe0645db95d6.jpg"

$sym_green = [char]::ConvertFromUtf32(0x1F7E2)

# Invisible characters
$em = [char]::ConvertFromUtf32(0x2003)
$en = [char]::ConvertFromUtf32(0x2002)
$braille = [char]::ConvertFromUtf32(0x2800)
$ideo = [char]::ConvertFromUtf32(0x3000)

$content = @"
**--- PRUEBA ESTRUCTURA [VACIO][VACIO]+[VACIO][VACIO]| ---**
$sym_green | Referencia (Emoji)

$braille$braille+$braille$braille| Prueba 1 (Braille)
$em$em+$em$em| Prueba 2 (Em Space)
$en$en+$en$en| Prueba 3 (En Space)
$ideo$ideo+$ideo$ideo| Prueba 4 (Ideographic Space)
"@

$payload = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = $content
}

$json = $payload | ConvertTo-Json
$temp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_invisible_custom.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp, $json, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp" $webhookUrl
Remove-Item -Path $temp -Force

Write-Host "Pruebas custom enviadas."
