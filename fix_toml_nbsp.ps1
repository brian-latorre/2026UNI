$tomlPath = "C:\Server2026UNI\config\simple-discord-link\simple-discord-link.toml"
$content = [System.IO.File]::ReadAllText($tomlPath)

$nbsp = [char]::ConvertFromUtf32(0x00A0)
$enDash = [char]::ConvertFromUtf32(0x2013)

# Build the strings with NBSP
$str_plus = $nbsp + $nbsp + "+" + $nbsp + $nbsp
$str_minus = $nbsp + $nbsp + $enDash + $nbsp + $nbsp
$str_star = $nbsp + $nbsp + "★" + $nbsp + $nbsp
$str_skull = $nbsp + $nbsp + "☠" + $nbsp + $nbsp

$content = $content -replace 'playerJoined = " \+  \| \*\*%player%\*\* ha entrado al servidor\."', ("playerJoined = `"" + $str_plus + "| **%player%** ha entrado al servidor.`"")
$content = $content -replace 'playerLeft = " -  \| \*\*%player%\*\* ha salido del servidor\."', ("playerLeft = `"" + $str_minus + "| **%player%** ha salido del servidor.`"")
$content = $content -replace 'advancements = " ★  \| \*\*%player%\*\* ha completado el progreso: \*\*\[%title%\]\*\*"', ("advancements = `"" + $str_star + "| **%player%** ha completado el progreso: **[%title%]**`"")
$content = $content -replace 'death = " ☠  \| \*\*%player%\*\* %message%"', ("death = `"" + $str_skull + "| **%player%** %message%`"")

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tomlPath, $content, $utf8NoBom)
Write-Host "Configuracion TOML actualizada con NBSP."
