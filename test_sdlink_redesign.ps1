$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$serverName = "Minecraft Server"
$serverAvatar = "https://i.pinimg.com/1200x/88/8b/a9/888ba992b024f21cc4effe0645db95d6.jpg"

$sym_refresh = [char]::ConvertFromUtf32(0x27F3)
$sym_check = [char]::ConvertFromUtf32(0x2713)
$sym_trophy = [char]::ConvertFromUtf32(0x1F3C6)
$sym_cross = [char]::ConvertFromUtf32(0x2715)
$sym_star_solid = [char]::ConvertFromUtf32(0x2726)
$sym_star_outline = [char]::ConvertFromUtf32(0x2727)

$content = @"
**--- VARIACION A: Estilo Consola/Corchetes ---**
[ $sym_refresh ] Inicializando el entorno del servidor...
[ $sym_check ] **Servidor en linea** y listo para jugar.
[ + ] **Notch** se ha conectado a la red.
[ $sym_trophy ] **Notch** ha completado el logro: **[Edad de Piedra]**
[ - ] **Notch** abandono la sesion.
[ $sym_cross ] El servidor se ha apagado.

**--- VARIACION B: Estilo Moderno/Minimalista ---**
$sym_refresh | Preparando el mundo...
$sym_check | **El servidor esta en linea**
$sym_star_solid | **Notch** se unio a la partida
$sym_trophy | **Notch** supero el desafio: **[Edad de Piedra]**
$sym_star_outline | **Notch** abandono la partida
$sym_cross | **El servidor esta apagado**
"@

$payload = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = $content
}

$json = $payload | ConvertTo-Json
$temp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_inline3.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp, $json, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp" $webhookUrl
Remove-Item -Path $temp -Force

Write-Host "Pruebas de rediseño corregidas enviadas."
