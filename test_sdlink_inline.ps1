$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$serverName = "Minecraft Server"
$serverAvatar = "https://i.pinimg.com/1200x/88/8b/a9/888ba992b024f21cc4effe0645db95d6.jpg"

$payload1 = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = "**Notch** ha entrado al servidor."
}

$json1 = $payload1 | ConvertTo-Json
$temp1 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_inline1.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp1, $json1, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp1" $webhookUrl
Remove-Item -Path $temp1 -Force

Start-Sleep -Seconds 1

$payload2 = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = "**Notch** ha salido del servidor."
}

$json2 = $payload2 | ConvertTo-Json
$temp2 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_inline2.json")
[System.IO.File]::WriteAllText($temp2, $json2, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp2" $webhookUrl
Remove-Item -Path $temp2 -Force

Write-Host "Pruebas inline enviadas."
