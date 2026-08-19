$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$serverName = "Minecraft Server"
$serverAvatar = "https://i.pinimg.com/1200x/88/8b/a9/888ba992b024f21cc4effe0645db95d6.jpg"

$nbsp = [char]::ConvertFromUtf32(0x00A0)
$enDash = [char]::ConvertFromUtf32(0x2013)

# Prueba A: 3 NBSP left, 2 NBSP right
$p_join   = ($nbsp * 3) + "+" + ($nbsp * 2)
$p_leave  = ($nbsp * 3) + $enDash + ($nbsp * 2)
$p_adv    = ($nbsp * 3) + "*" + ($nbsp * 2)
$p_death  = ($nbsp * 3) + "x" + ($nbsp * 2)
$p_cmd    = ($nbsp * 3) + "!" + ($nbsp * 2)
$p_wl_add = ($nbsp * 3) + "+" + ($nbsp * 2)
$p_wl_rem = ($nbsp * 3) + "-" + ($nbsp * 2)
$p_say    = ($nbsp * 3) + ">" + ($nbsp * 2)

$sym_yellow = [char]::ConvertFromUtf32(0x1F7E1)
$sym_green  = [char]::ConvertFromUtf32(0x1F7E2)
$sym_red    = [char]::ConvertFromUtf32(0x1F534)
$sym_black  = [char]::ConvertFromUtf32(0x26AB)

$content = @"
**--- 1. ESTADO DEL SERVIDOR ---**
$sym_yellow | Iniciando el servidor... Preparando el mundo.
$sym_green | **Servidor en línea.** Ya pueden entrar a jugar.
$sym_red | **El servidor se está apagando...**
$sym_black | **Servidor apagado.**

**--- 2. SESIONES Y JUGABILIDAD ---**
$p_join| **Notch** ha entrado al servidor.
$p_leave| **Notch** ha salido del servidor.
$p_adv| **Notch** ha completado el progreso: **[Edad de Piedra]**
$p_death| **Notch** fue explotado por un Creeper.

**--- 3. CONTROL ADMINISTRATIVO Y MONITOREO ---**
$p_cmd| **Notch** ejecutó: `/gamemode creative Notch`
$p_cmd| **Notch** ejecutó: `/give Notch diamond 64`
$p_wl_add| **Alex** ha sido añadido a la lista blanca.
$p_wl_rem| **Steve** ha sido removido de la lista blanca.
$p_say| **[Servidor]:** Reinicio programado en 10 minutos.
"@

$payload = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = $content
}

$json = $payload | ConvertTo-Json
$temp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_all_features.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp, $json, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp" $webhookUrl
Remove-Item -Path $temp -Force

Write-Host "Simulacion completa enviada."
