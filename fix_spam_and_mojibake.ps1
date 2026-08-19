$tomlPath = "C:\Server2026UNI\config\simple-discord-link\simple-discord-link.toml"
$content = [System.IO.File]::ReadAllText($tomlPath)

# Revert command broadcasting and whitelist logging to stop spam
$content = $content -replace 'broadcastCommands = true', 'broadcastCommands = false'
$content = $content -replace 'whitelistChanged = true', 'whitelistChanged = false'

# Fix Mojibake by replacing with clean unaccented vowels
$content = $content -replace 'lÃ­nea', 'linea'
$content = $content -replace 'estÃ¡', 'esta'
$content = $content -replace 'aÃ±adido', 'anadido'
$content = $content -replace 'ejecutÃ³', 'ejecuto'

# Extra safety: Also replace normal accented letters if they somehow exist to prevent future Mojibake from Java reading them
$content = $content -replace 'línea', 'linea'
$content = $content -replace 'está', 'esta'
$content = $content -replace 'añadido', 'anadido'
$content = $content -replace 'ejecutó', 'ejecuto'

[System.IO.File]::WriteAllText($tomlPath, $content)
Write-Host "Arreglado: Spam desactivado y tildes limpiadas."
