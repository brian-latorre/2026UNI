$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$serverName = "Minecraft Server"
$serverAvatar = "https://i.pinimg.com/1200x/88/8b/a9/888ba992b024f21cc4effe0645db95d6.jpg"

$sym_yellow = [char]::ConvertFromUtf32(0x1F7E1)
$sym_green = [char]::ConvertFromUtf32(0x1F7E2)
$sym_red = [char]::ConvertFromUtf32(0x1F534)
$sym_black = [char]::ConvertFromUtf32(0x26AB)
$sym_in = [char]::ConvertFromUtf32(0x00BB) # »
$sym_out = [char]::ConvertFromUtf32(0x00AB) # «
$sym_star = [char]::ConvertFromUtf32(0x2605) # ★
$sym_skull = [char]::ConvertFromUtf32(0x2620) # ☠

$content = @"
**--- VARIACION C: Servidor con Color / Jugadores Limpios ---**
$sym_yellow Iniciando el servidor...
$sym_green **Servidor en linea.** Ya pueden entrar a jugar.
$sym_red **El servidor se esta apagando...**
$sym_black **Servidor apagado.**

$sym_in **Notch** ha entrado al servidor.
$sym_out **Notch** ha salido del servidor.
$sym_star **Notch** ha completado el progreso: **[Edad de Piedra]**
$sym_skull **Notch** fue explotado por un Creeper.

**--- VARIACION D: Todo con Bloques de Alineacion ---**
`$sym_yellow` Iniciando el servidor...
`$sym_green` **Servidor en linea.** Ya pueden entrar a jugar.
`$sym_red` **El servidor se esta apagando...**
`$sym_black` **Servidor apagado.**

` + ` **Notch** ha entrado al servidor.
` - ` **Notch** ha salido del servidor.
` ★ ` **Notch** ha completado el progreso: **[Edad de Piedra]**
` ☠ ` **Notch** fue explotado por un Creeper.
"@

$payload = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = $content
}

$json = $payload | ConvertTo-Json
$temp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_inline_colors.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp, $json, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp" $webhookUrl
Remove-Item -Path $temp -Force

Write-Host "Pruebas de color enviadas."
