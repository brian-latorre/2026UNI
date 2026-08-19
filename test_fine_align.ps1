$webhookUrl = "https://discord.com/api/webhooks/1530317872029634591/3dZjpJ4BQGjcwlXeCQ7MN3dxpnPwb1anR7S5P37oZv5pcGyvNXtTZp6BKhusq1ZWH_Bk"

$serverName = "Minecraft Server"
$serverAvatar = "https://i.pinimg.com/1200x/88/8b/a9/888ba992b024f21cc4effe0645db95d6.jpg"

$nbsp = [char]::ConvertFromUtf32(0x00A0)
$enDash = [char]::ConvertFromUtf32(0x2013)
$sym_green = [char]::ConvertFromUtf32(0x1F7E2)

# Variations of left/right padding
# 1) 3 NBSP left, 2 NBSP right
$p1_plus  = ($nbsp * 3) + "+" + ($nbsp * 2)
# 2) 4 NBSP left, 2 NBSP right
$p2_plus  = ($nbsp * 4) + "+" + ($nbsp * 2)
# 3) 2 NBSP left, 3 NBSP right
$p3_plus  = ($nbsp * 2) + "+" + ($nbsp * 3)
# 4) 3 NBSP left, 3 NBSP right
$p4_plus  = ($nbsp * 3) + "+" + ($nbsp * 3)
# 5) 1 NBSP left, 1 space, +, 2 NBSP right
$p5_plus  = ($nbsp * 1) + " " + "+" + ($nbsp * 2)

$content = @"
**--- TEST DE AJUSTE FINO DE ESPACIADO IZQUIERDO ---**
$sym_green | Referencia: Servidor en linea.

$p1_plus| Prueba A (3 espacios izq + 2 der)
$p2_plus| Prueba B (4 espacios izq + 2 der)
$p3_plus| Prueba C (2 espacios izq + 3 der)
$p4_plus| Prueba D (3 espacios izq + 3 der)
$p5_plus| Prueba E (1 NBSP + 1 space + 2 NBSP)
"@

$payload = @{
    username = $serverName
    avatar_url = $serverAvatar
    content = $content
}

$json = $payload | ConvertTo-Json
$temp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_fine_align.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($temp, $json, $utf8NoBom)
curl.exe -s -H "Content-Type: application/json" -d "@$temp" $webhookUrl
Remove-Item -Path $temp -Force

Write-Host "Test de espaciado fino enviado."
