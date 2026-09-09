import os
from datetime import datetime
import locale

locale.setlocale(locale.LC_TIME, '')
today = datetime.now()
file_path = f"C:\\Node\\Diario\\{today.year}\\{today.month:02d}\\{today.year}-{today.month:02d}-{today.day:02d}.md"

entry = """
### Intervención IA: Resolución de PineconeMC y SyncMesh (Bug de Eliminación de Mods)

**Problema Inicial:** 
El modpack de PineconeMC no eliminaba los archivos `.jar` (como `findme`) cuando estos eran removidos del Cliente Madre y publicados vía SyncMesh. Además, GitHub Actions fallaba la publicación con un error de `Key 'files.preserve' has already been defined`.

**Causa Raíz Encontrada:**
1. **GitHub Actions (TOML Syntax Error):** Falla en el parseador de Python `core/packwiz_parser.py` que inyectaba `preserve = true` múltiples veces para el mismo archivo.
2. **PineconeMC (Ghost Mods):** Defecto arquitectónico en `pre-launch.bat` de la instancia. Al ser ejecutado desde la raíz de la instancia (`instances/2026UNI`) en lugar de `.minecraft`, `packwiz-installer` no generaba el caché local (`packwiz.json`). Al no tener memoria de su estado previo, el instalador no borraba ningún archivo viejo, solo descargaba los nuevos.

**Solución Implementada:**
- Se reescribió `packwiz_parser.py` para usar expresiones regulares que limpian por completo las directivas previas antes de inyectar las nuevas, evitando cualquier duplicado TOML de raíz.
- Se añadió el comando `cd /d "%MC_DIR%"` a todos los scripts `pre-launch.bat` (`pack/`, `pack-lite/` y `instance-template/`) asegurando que el instalador opere en el entorno correcto y guarde su historial (`packwiz.json`).
- Se le notificó al usuario que una forma de limpiar la instancia actual de los jugadores es pedirles que usen la opción "Restaurador General" de la herramienta `GUI-Configurador.ps1`.
- SyncMesh funcionó perfectamente y no fue responsable de la acumulación de basura en los clientes.
"""

os.makedirs(os.path.dirname(file_path), exist_ok=True)
if not os.path.exists(file_path):
    with open(file_path, "w", encoding="utf-8") as f:
        f.write("# " + today.strftime("%A, %d de %B de %Y").capitalize() + "\n")
        f.write(entry)
else:
    with open(file_path, "a", encoding="utf-8") as f:
        f.write("\n" + entry)
