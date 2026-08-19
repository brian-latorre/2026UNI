$tomlPath = "C:\Server2026UNI\config\simple-discord-link\simple-discord-link.toml"
$bytes = [System.IO.File]::ReadAllBytes($tomlPath)
$content = [System.Text.Encoding]::UTF8.GetString($bytes)

$nbsp = [char]::ConvertFromUtf32(0x00A0)
$enDash = [char]::ConvertFromUtf32(0x2013)

# Prueba A spacing
$p_join   = ($nbsp * 3) + "+" + ($nbsp * 2)
$p_leave  = ($nbsp * 3) + $enDash + ($nbsp * 2)
$p_adv    = ($nbsp * 3) + "*" + ($nbsp * 2)
$p_death  = ($nbsp * 3) + "x" + ($nbsp * 2)
$p_cmd    = ($nbsp * 3) + "!" + ($nbsp * 2)
$p_wl_add = ($nbsp * 3) + "+" + ($nbsp * 2)
$p_wl_rem = ($nbsp * 3) + $enDash + ($nbsp * 2)
$p_say    = ($nbsp * 3) + ">" + ($nbsp * 2)

$sym_yellow = [char]::ConvertFromUtf32(0x1F7E1)
$sym_green  = [char]::ConvertFromUtf32(0x1F7E2)
$sym_red    = [char]::ConvertFromUtf32(0x1F534)
$sym_black  = [char]::ConvertFromUtf32(0x26AB)

# 1. Enable command broadcast & full commands
$content = $content -replace 'broadcastCommands = false', 'broadcastCommands = true'
$content = $content -replace 'relayFullCommands = false', 'relayFullCommands = true'
$content = $content -replace 'whitelistChanged = false', 'whitelistChanged = true'
$content = $content -replace 'ignoredCommands = \["particle", "login", "execute", "sdconfigeditor"\]', 'ignoredCommands = ["login", "register", "particle", "execute", "sdconfigeditor", "msg", "w", "tell", "r"]'

# 2. Update all messageFormatting strings
$newFormatting = @"
	#Server Starting Message
	serverStarting = "$sym_yellow | Iniciando el servidor... Preparando el mundo."
	#Server Started Message
	serverStarted = "$sym_green | **Servidor en línea.** Ya pueden entrar a jugar."
	#Server Stopping Message
	serverStopping = "$sym_red | **El servidor se está apagando...**"
	#Server Stopped Message
	serverStopped = "$sym_black | **Servidor apagado.**"
	#Player Joined Message. Use %player% to display the player name
	playerJoined = "$p_join| **%player%** ha entrado al servidor."
	#Player Left Message. Use %player% to display the player name
	playerLeft = "$p_leave| **%player%** ha salido del servidor."
	#Advancement Messages. Available variables: %player%, %title%, %description%
	advancements = "$p_adv| **%player%** ha completado el progreso: **[%title%]**"
	#Chat Messages. THIS DOES NOT APPLY TO EMBED OR WEBHOOK MESSAGES. Available variables: %player%, %message%, %mcname%
	chat = "%player%: %message%"
	#Death Messages. Available variables: %player%, %message%
	death = "$p_death| **%player%** %message%"
	#Message to be sent when a player is added to the whitelist
	whitelistAdded = "$p_wl_add| **%player%** ha sido añadido a la lista blanca."
	#Message to be sent when a player is removed from the whitelist
	whitelistRemoved = "$p_wl_rem| **%player%** ha sido removido de la lista blanca."
	#Command Messages. Available variables: %player%, %command%
	commands = "$p_cmd| **%player%** ejecutó: ``/%command%``"
"@

$regex = '(?s)#Server Starting Message.*#Command Messages\. Available variables: %player%, %command%\r?\n\tcommands = "[^"]*"'
$content = [regex]::Replace($content, $regex, $newFormatting)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tomlPath, $content, $utf8NoBom)
Write-Host "Configuracion global de SDLink aplicada con exito en UTF-8."
