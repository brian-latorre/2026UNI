$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$serverName = "Minecraft Server"
$serverAvatar = "https://i.pinimg.com/1200x/88/8b/a9/888ba992b024f21cc4effe0645db95d6.jpg"

$sym_green = [char]::ConvertFromUtf32(0x1F7E2)

$content = @"
**--- PRUEBA DE ESPACIOS NORMALES ---**
$sym_green | Referencia (Emoji)

 + | Prueba 1 (1 espacio + 1 espacio)
  + | Prueba 2 (2 espacios + 1 espacio)
 +  | Prueba 3 (1 espacio + 2 espacios)
  +  | Prueba 4 (2 espacios + 2 espacios)
   +  | Prueba 5 (3 espacios + 2 espacios)
  +   | Prueba 6 (2 espacios + 3 espacios)
   +   | Prueba 7 (3 espacios + 3 espacios)
"@

$payload = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = $content
}

$json = $payload | ConvertTo-Json
$temp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_spaces.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp, $json, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp" $webhookUrl
Remove-Item -Path $temp -Force

Write-Host "Pruebas de espacios enviadas."
