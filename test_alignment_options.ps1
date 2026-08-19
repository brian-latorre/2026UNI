$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$serverName = "Minecraft Server"
$serverAvatar = "https://i.pinimg.com/1200x/88/8b/a9/888ba992b024f21cc4effe0645db95d6.jpg"

$nbsp = [char]::ConvertFromUtf32(0x00A0)

# Option 1: ASCII Only (+, -, *, x)
$opt1_yellow = [char]::ConvertFromUtf32(0x1F7E1)
$opt1_green  = [char]::ConvertFromUtf32(0x1F7E2)
$opt1_plus   = $nbsp + $nbsp + "+" + $nbsp + $nbsp
$opt1_minus  = $nbsp + $nbsp + [char]::ConvertFromUtf32(0x2013) + $nbsp + $nbsp
$opt1_star   = $nbsp + $nbsp + "*" + $nbsp + $nbsp
$opt1_cross  = $nbsp + $nbsp + "x" + $nbsp + $nbsp

# Option 2: Full Emojis (Perfect Width Matching)
$opt2_yellow = [char]::ConvertFromUtf32(0x1F7E1)
$opt2_green  = [char]::ConvertFromUtf32(0x1F7E2)
$opt2_in     = [char]::ConvertFromUtf32(0x1F4E5) # 📥
$opt2_out    = [char]::ConvertFromUtf32(0x1F4E4) # 📤
$opt2_trophy = [char]::ConvertFromUtf32(0x1F3C6) # 🏆
$opt2_skull  = [char]::ConvertFromUtf32(0x1F480) # 💀

# Option 3: Monospace code ticks on prefix
$content = @"
**--- OPCION 1: Solo Caracteres ASCII (+, -, *, x) ---**
$opt1_yellow | Iniciando el servidor...
$opt1_green | **Servidor en linea.** Ya pueden entrar a jugar.
$opt1_plus| **Notch** ha entrado al servidor.
$opt1_minus| **Notch** ha salido del servidor.
$opt1_star| **Notch** ha completado el progreso: **[Edad de Piedra]**
$opt1_cross| **Notch** fue explotado por un Creeper.

**--- OPCION 2: Todos los íconos como Emojis (Alineación 100% idéntica) ---**
$opt2_yellow | Iniciando el servidor...
$opt2_green | **Servidor en linea.** Ya pueden entrar a jugar.
$opt2_in | **Notch** ha entrado al servidor.
$opt2_out | **Notch** ha salido del servidor.
$opt2_trophy | **Notch** ha completado el progreso: **[Edad de Piedra]**
$opt2_skull | **Notch** fue explotado por un Creeper.

**--- OPCION 3: Fuente Monocromática / Monospace en Prefijo ---**
` 🟢 ` | **Servidor en linea.** Ya pueden entrar a jugar.
`  +  ` | **Notch** ha entrado al servidor.
`  -  ` | **Notch** ha salido del servidor.
`  *  ` | **Notch** ha completado el progreso: **[Edad de Piedra]**
`  x  ` | **Notch** fue explotado por un Creeper.
"@

$payload = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = $content
}

$json = $payload | ConvertTo-Json
$temp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_alignment_options.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp, $json, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp" $webhookUrl
Remove-Item -Path $temp -Force

Write-Host "Opciones de alineacion enviadas."
