$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$serverName = "Minecraft Server"
$serverAvatar = "https://i.pinimg.com/1200x/88/8b/a9/888ba992b024f21cc4effe0645db95d6.jpg"

$sym_refresh = [char]::ConvertFromUtf32(0x27F3)
$sym_check   = [char]::ConvertFromUtf32(0x2713)
$sym_warn    = [char]::ConvertFromUtf32(0x26A0)
$sym_cross   = [char]::ConvertFromUtf32(0x2717)
$sym_join    = [char]::ConvertFromUtf32(0x2726)
$sym_leave   = [char]::ConvertFromUtf32(0x2727)
$sym_achieve = [char]::ConvertFromUtf32(0x2756)
$sym_death   = [char]::ConvertFromUtf32(0x2620)

$content = @"
**--- MENSAJES DE ESTADO DEL SERVIDOR ---**
$sym_refresh | Iniciando el servidor...
$sym_check | **Servidor en linea.** Ya pueden entrar a jugar.
$sym_warn | **El servidor se esta apagando...**
$sym_cross | **Servidor apagado.**

**--- MENSAJES DE JUGADORES ---**
$sym_join | **Notch** ha entrado al servidor.
$sym_leave | **Notch** ha salido del servidor.
$sym_achieve | **Notch** ha completado el progreso: **[Edad de Piedra]**
$sym_death | **Notch** fue explotado por un Creeper.
"@

$payload = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = $content
}

$json = $payload | ConvertTo-Json
$temp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_inline_aligned.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp, $json, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp" $webhookUrl
Remove-Item -Path $temp -Force

Write-Host "Pruebas alineadas enviadas."
