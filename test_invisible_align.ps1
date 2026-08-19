$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$serverName = "Minecraft Server"
$serverAvatar = "https://i.pinimg.com/1200x/88/8b/a9/888ba992b024f21cc4effe0645db95d6.jpg"

$sym_green = [char]::ConvertFromUtf32(0x1F7E2)

# Invisible characters
$em_space = [char]::ConvertFromUtf32(0x2003)
$en_space = [char]::ConvertFromUtf32(0x2002)
$braille = [char]::ConvertFromUtf32(0x2800)
$ideo_space = [char]::ConvertFromUtf32(0x3000)
$fig_space = [char]::ConvertFromUtf32(0x2007)

$content = @"
**--- PRUEBA DE ALINEACION INVISIBLE ---**
$sym_green | Referencia (Emoji)

$em_space+ | Prueba 1 (Em Space)
$en_space$en_space+ | Prueba 2 (2x En Space)
$braille$braille+ | Prueba 3 (2x Braille Blank)
$ideo_space+ | Prueba 4 (Ideographic Space)
$em_space$fig_space+ | Prueba 5 (Em + Fig Space)
$braille $braille+ | Prueba 6 (Braille + Space + Braille)
$braille$braille + | Prueba 7 (2x Braille + Space)
"@

$payload = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = $content
}

$json = $payload | ConvertTo-Json
$temp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_invisible.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp, $json, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp" $webhookUrl
Remove-Item -Path $temp -Force

Write-Host "Pruebas de caracteres invisibles enviadas."
