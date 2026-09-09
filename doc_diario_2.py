import os
from datetime import datetime
import locale

locale.setlocale(locale.LC_TIME, '')
today = datetime.now()
file_path = f"C:\\Node\\Diario\\{today.year}\\{today.month:02d}\\{today.year}-{today.month:02d}-{today.day:02d}.md"

entry = """
### Parte 2: Reparación del "Restaurador General" y limpieza automática
El usuario reportó que el botón "Reparar Todo" del Configurador no eliminaba la carpeta mods.
Se investigó la arquitectura y se halló un bug de resolución de directorios en todos los `.ps1` de la carpeta `modules`:
- Los scripts asumían estar en `pack\scripts\modules` (entorno Dev), usando `..\..\` para alcanzar las carpetas `mods` y `config`.
- En el cliente (PineconeMC), están en `.minecraft\scripts\modules`, por lo que `..\..\` apuntaba a `instances/2026UNI/mods`, carpeta inexistente, causando que el comando `Remove-Item` fallara silenciosamente.
- **Solución:** Se escribió un script de Python que modificó masivamente todos los archivos `.ps1` en los 3 repositorios locales (`pack`, `pack-lite` y `instance-template`) cambiando `..\..\` por `..\`.

Finalmente, para que los jugadores NO tengan que abrir el configurador ni borrar los mods a mano, se añadió un parche temporal directo en el `pre-launch.bat` (que se distribuirá en la siguiente actualización):
`if exist "%MC_DIR%\mods\findme-*.jar" del /q "%MC_DIR%\mods\findme-*.jar"`
De esta forma, todo mod huérfano será purgado automáticamente al presionar Jugar.
"""

if os.path.exists(file_path):
    with open(file_path, "a", encoding="utf-8") as f:
        f.write("\n" + entry)
