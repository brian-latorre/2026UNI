# Documentación del Flujo de Publicación (2026UNI)

Este documento detalla el funcionamiento interno de `Publicar-Actualizacion.bat` y todo el pipeline de actualización del modpack. Entender este flujo te ayudará a evitar problemas al actualizar mods propios o configuraciones.

## 1. El Punto de Entrada: `Publicar-Actualizacion.bat`
Este es un archivo Batch simple que actúa como un lanzador. Su única función real es configurar la consola para que soporte colores y caracteres especiales (UTF-8) y luego delegar todo el trabajo pesado al script principal en PowerShell: `scripts\publish.ps1`.

## 2. El Cerebro de la Operación: `publish.ps1`
Este script coordina los 5 pasos fundamentales para garantizar que los clientes reciban las actualizaciones.

### Paso 1: Sincronización de Overrides Locales
El script **no lee de tu servidor de producción**. En su lugar, lee de tu "Cliente Madre" (el entorno de pruebas):
`C:\Users\brian\AppData\Roaming\.minecraft\2026UNI`

Copia todas las carpetas clave de configuraciones (`config`, `resourcepacks`, `shaderpacks`, `showdown`, `emojiful`, etc.) hacia la carpeta `pack\` del repositorio.
**Regla de oro:** Si quieres cambiar una configuración para todos los usuarios, debes cambiarla primero en tu Cliente Madre.

### Paso 2: Auto-Detección de Mods (`auto-import-mods.py`)
Aquí es donde ocurre la magia (y la confusión frecuente con mods propios).
Este script en Python compara la carpeta `mods` de tu Cliente Madre con la carpeta `pack/mods/` del repositorio.

1. **Detecta mods eliminados:** Si borraste un mod en tu cliente, lo borra del repositorio.
2. **Detecta mods nuevos de Modrinth/CurseForge:** Si añadiste un mod conocido, busca su metadato en las APIs y crea un archivo `.pw.toml`. Esto permite descargar el mod directo de los servidores originales, ahorrando ancho de banda.
3. **Manejo de Mods Locales (Tus propios mods):**
   - Si tienes un mod tuyo (como `Emojiful-fork`), Python verifica si el **Hash SHA-1** del archivo `.jar` en tu cliente es diferente al que ya está guardado en `pack/mods`.
   - **IMPORTANTE:** El Hash cambia única y exclusivamente cuando **compilas** el mod generando un nuevo archivo interno. Cambiar el nombre del archivo no altera el Hash; cambiar el código sí lo hace.
   - Si el Hash es diferente, sobreescribe el `.jar` antiguo en `pack/mods` con el nuevo. Si el Hash es igual, lo ignora (asume que no hay cambios).

### Paso 3: Construcción y Validación (`build-pack.ps1` y `fix-blocked-mods.ps1`)
Este paso regenera el "índice" que usa el launcher de los jugadores para saber qué descargar.

1. **Resolución de Bloqueos:** `fix-blocked-mods.ps1` revisa si CurseForge ha bloqueado la descarga de algún mod de terceros (como *tombstone* o *adorablehamsterpets*). Si es así, extrae el archivo `.jar` crudo de tu Cliente Madre para enviarlo directamente.
2. **Packwiz Refresh:** Packwiz escanea toda la carpeta `pack/` y actualiza el archivo maestro `index.toml`. Para cada archivo (incluyendo tu `.jar` de Emojiful), Packwiz calcula un **Hash SHA-256** y lo guarda en el índice.
3. **Protección del Jugador:** Se inyecta la directiva `preserve = true` a archivos sensibles como `options.txt` para que al actualizar, no se le borre la configuración gráfica ni los controles a los jugadores.

### Paso 4: Empaquetado y Subida (Git)
Se incrementa la versión del archivo `version.json` (que usa el launcher web o el sistema de notificaciones).
El script usa Git para registrar todos los cambios (el nuevo `index.toml`, los nuevos `.jar`, configuraciones modificadas) y realiza un `git push` a GitHub (rama `main`).

### Paso 5: Despliegue en GitHub Actions
El script se queda esperando verificando que GitHub Actions construya la versión descargable sin errores.

---

## 3. ¿Cómo sabe el Launcher (PineconeMC) que debe actualizar un Mod?
El launcher usa el sistema `packwiz-installer`. Cuando el jugador abre el launcher:

1. El launcher descarga el `index.toml` más reciente desde GitHub.
2. Compara el **Hash SHA-256** de cada archivo listado en el `index.toml` de internet contra el archivo físico que el jugador tiene en su disco duro.
3. **Si el Hash coincide:** Lo ignora (el archivo está actualizado).
4. **Si el Hash es distinto:** Descarga la versión nueva desde internet, sobrescribiendo el archivo viejo.

### Resumen del Flujo para Desarrollar un Mod Propio:
1. Haces un cambio en tu código Java.
2. Ejecutas **`gradlew build`** en tu entorno de desarrollo. Esto crea un `.jar` con un **Hash nuevo**.
3. Copias manualmente ese nuevo `.jar` a `C:\Users\brian\AppData\Roaming\.minecraft\2026UNI\mods` (reemplazando al viejo).
4. Ejecutas `Publicar-Actualizacion.bat`.
5. El sistema detecta el Hash diferente, lo sube, y los launchers de los usuarios lo descargan por tener un Hash distinto.
