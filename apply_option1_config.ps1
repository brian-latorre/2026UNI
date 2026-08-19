$tomlPath = "C:\Server2026UNI\config\simple-discord-link\simple-discord-link.toml"
$content = [System.IO.File]::ReadAllText($tomlPath)

$nbsp = [char]::ConvertFromUtf32(0x00A0)
$enDash = [char]::ConvertFromUtf32(0x2013)

# Build Option 1 strings with NBSP
$str_plus  = $nbsp + $nbsp + "+" + $nbsp + $nbsp
$str_minus = $nbsp + $nbsp + $enDash + $nbsp + $nbsp
$str_star  = $nbsp + $nbsp + "*" + $nbsp + $nbsp
$str_cross = $nbsp + $nbsp + "x" + $nbsp + $nbsp

$newFormatting = @"
	#Server Starting Message
	serverStarting = "🟡 | Iniciando el servidor... Preparando el mundo."
	#Server Started Message
	serverStarted = "🟢 | **Servidor en línea.** Ya pueden entrar a jugar."
	#Server Stopping Message
	serverStopping = "🔴 | **El servidor se está apagando...**"
	#Server Stopped Message
	serverStopped = "⚫ | **Servidor apagado.**"
	#Player Joined Message. Use %player% to display the player name
	playerJoined = "$str_plus| **%player%** ha entrado al servidor."
	#Player Left Message. Use %player% to display the player name
	playerLeft = "$str_minus| **%player%** ha salido del servidor."
	#Advancement Messages. Available variables: %player%, %title%, %description%
	advancements = "$str_star| **%player%** ha completado el progreso: **[%title%]**"
	#Chat Messages. THIS DOES NOT APPLY TO EMBED OR WEBHOOK MESSAGES. Available variables: %player%, %message%, %mcname%
	chat = "%player%: %message%"
	#Death Messages. Available variables: %player%, %message%
	death = "$str_cross| **%player%** %message%"
"@

# Regex replacement for the entire block under [messageFormatting]
$regex = '(?s)#Server Starting Message.*#Message to be sent when a player is added to the whitelist'

$replacement = $newFormatting + "`n`t#Message to be sent when a player is added to the whitelist"

$content = [regex]::Replace($content, $regex, $replacement)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tomlPath, $content, $utf8NoBom)
Write-Host "Configuracion de la Opcion 1 aplicada correctamente."
