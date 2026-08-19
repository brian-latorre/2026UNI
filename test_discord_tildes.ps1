# Script de prueba para envío de Tildes y Emojis Literales en PS 5.1 con BOM

$b64Webhook = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUzMDMxNzg3MjAyOTYzNDU5MS8zZFpqcEo0QlFHamN3bFhlQ1E3TU4zZHhwblB3YjFhblI3UzVQMzdvWnY1cGNHeXZOWHRUWnA2QktodXNxMVpXSF9Caw==" 
$webhookUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($b64Webhook))

$payloadObj = @{}
$payloadObj.content = "Prueba Definitiva: Tildes y Ñ (Sesión, Híbrido, Árbol, Ñandú) con UTF-8 BOM"

$embed = @{
    title = "📈 [LOG] Sesión de Juego Finalizada (Con Tildes)"
    description = "El jugador ha cerrado el menú de configuración y la sesión finalizó."
    color = 65280 # Verde
    fields = @(
        @{ name = "👤 Usuario"; value = "**PruebaUser**"; inline = $false },
        @{ name = "⏳ Tiempo de Sesión"; value = "50.1 minutos"; inline = $true },
        @{ name = "📈 Tiempo Total Jugado"; value = "2.6 horas totales"; inline = $true },
        @{ name = [char]0x200B; value = [char]0x200B; inline = $true },
        @{ name = "▶️ Hora de Inicio"; value = "18/08/2026 10:13:42"; inline = $true },
        @{ name = "⏹️ Hora de Cierre"; value = "18/08/2026 11:03:46"; inline = $true },
        @{ name = [char]0x200B; value = [char]0x200B; inline = $true }
    )
}
$payloadObj.embeds = @($embed)

$jsonString = $payloadObj | ConvertTo-Json -Depth 5
$tempJsonPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "test_payload.json")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tempJsonPath, $jsonString, $utf8NoBom)

curl.exe -s -H "Content-Type: application/json" -d "@$tempJsonPath" $webhookUrl
Remove-Item -Path $tempJsonPath -Force
