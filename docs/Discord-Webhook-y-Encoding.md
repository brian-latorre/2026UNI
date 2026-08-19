# Documentación Técnica: Webhooks de Discord y Encoding en PowerShell 5.1

## 1. El Problema del Mojibake (Caracteres Corruptos)
Al desarrollar el reportero de Logs (`enviar-logs.ps1`), se detectó que los Emojis y caracteres con tilde se enviaban a Discord como símbolos corruptos (ej. `ðŸ'¤`, `HÃbrido`).

### Causa Raíz
El motor nativo de Windows (PowerShell 5.1) lee los scripts desde el disco asumiendo codificación ANSI (Windows-1252) a menos que el archivo tenga explícitamente un marcador BOM (Byte Order Mark). Si un editor de código guarda el script en UTF-8 sin BOM, PowerShell interpreta los bytes multibyte de los emojis como múltiples caracteres ANSI.

### Solución Implementada 1: Para Tildes y Caracteres en el Código (UTF-8 con BOM)
Si se desea utilizar tildes o caracteres como `Ñ` directamente en las strings de PowerShell (ej. `"Sesión finalizada"`), el archivo `.ps1` debe guardarse obligatoriamente con la codificación **UTF-8 con BOM (Byte Order Mark)**. Esto le indica físicamente a PowerShell 5.1 que lea el archivo en UTF-8 y no en ANSI.
*Nota de mantenimiento:* Si editas el archivo en un editor como VS Code que guarda por defecto en UTF-8 sin BOM, volverás a corromper las tildes.

### Solución Implementada 2: Para Emojis (Totalmente a prueba de fallos)
Para garantizar que los emojis nunca se corrompan (incluso si se pierde el BOM del archivo), se construyen en la memoria de forma hexadecimal usando la API de .NET:
```powershell
$e_Usuario = [char]::ConvertFromUtf32(0x1F464) # Genera 👤
$e_Tiempo  = [char]::ConvertFromUtf32(0x23F3)  # Genera ⏳
```
Luego, al exportar el Payload a JSON para enviarlo vía Webhook, se fuerza la codificación UTF-8 pura sin BOM:
```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($jsonPath, $jsonString, $utf8NoBom)
```

## 2. El Problema del Layout (Grid en Discord)
Discord renderiza los Embeds en su versión de escritorio permitiendo hasta 3 campos `inline=true` por fila. Si se envían 4 campos, el resultado es asimétrico (3 arriba, 1 abajo), rompiendo la estructura de la información.

### Solución Implementada: "Phantom Fields"
Para forzar una distribución perfectamente simétrica de 2 columnas por fila, se inyectan "campos fantasma" que contienen el carácter de espacio de ancho cero (`Zero-Width Space`, Unicode `U+200B`):
```powershell
@{ name = [char]0x200B; value = [char]0x200B; inline = $true }
```
Este campo ocupa la tercera columna (forzando a Discord a completar el ancho del contenedor virtual), haciendo que los siguientes elementos salten y se rendericen limpiamente en la siguiente línea. Al combinar esta táctica de forma intercalada, se garantiza un diseño en cuadrícula 2x2.

## 3. La Fusión: PowerShell + Webhooks
Al unir ambas soluciones, el script final es capaz de:
1. Extraer nombres de usuario y logs masivos desde `.session_lock` o `latest.log`.
2. Evadir la corrupción de caracteres mediante declaración hexadecimal.
3. Formatear la salida visual usando trucos de UI de Discord (`Phantom Fields`).
4. Compilar un `payload.json` en UTF-8 nativo y dispararlo junto con adjuntos a través de la herramienta nativa de Windows `curl.exe`.
