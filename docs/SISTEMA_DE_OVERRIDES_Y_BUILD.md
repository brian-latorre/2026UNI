# El Sistema de Overrides y Construcción del Pack

Este documento detalla la arquitectura de sincronización de configuraciones y preparación final del empaquetado para su despliegue, guiado por los scripts `sync-overrides.ps1` y `build-pack.ps1`.

---

## 1. El Gestor de Overrides (`sync-overrides.ps1`)

Este script se encarga de clonar todo lo que **no son mods auto-gestionados** desde tu Cliente Madre local hacia la carpeta del repositorio (`pack/` o `pack-lite/`). Actúa como un puente entre tu juego de pruebas y el servidor de descargas.

### ¿Qué SÍ se sincroniza?
Se copian en modo espejo (se reemplaza y elimina lo obsoleto):
*   **Carpetas:** `config/`, `defaultconfigs/`, `emojiful/`, `emotes/`, `fancymenu_data/`, `otyacraftengine/`, `resourcepacks/`, `shaderpacks/`, `scripts/`, `presets_graficos/`.
*   **Archivos sueltos:** `options.txt`, `servers.dat`, `Configurador Grafico.bat`.

### ¿Qué se EXCLUYE explícitamente?
Para no ensuciar el repositorio de Git ni enviar información confidencial (o configuraciones temporales) a los jugadores, se bloquean:
*   Carpetas: `.git`, `.cache`, `url_texture_cache`, `__pycache__`.
*   Archivos: `username_cache.json`, `*.log`, `*.tmp`, `voicechat-client.toml`, `client.json`, `desktop.ini`.
*   *(Nota histórica: `embeddium-options.json` y `oculus.properties` solían excluirse aquí por dar problemas con los menús de video, pero ahora se incluyen obligatoriamente para que Packwiz los gestione de forma segura).*

### La Sincronización Inteligente de JARs
Recientemente, se añadió una lógica vital para los "Mods Sueltos" (los que no tienen versión en CurseForge/Modrinth):
1. Analiza el directorio de destino y lee todos los `.pw.toml` para saber qué mods ya se descargan de la nube y no requieren tocarse.
2. Compara eso con los archivos `.jar` de la instancia Cliente Madre.
3. Copia directo los `.jar` huérfanos que el desarrollador haya introducido localmente y borra los `.jar` sueltos que ya no existan en la instalación origen.

---

## 2. El Empaquetado y Protección (`build-pack.ps1`)

Una vez que los archivos locales se han movido a las carpetas del repositorio, `build-pack.ps1` se ejecuta para consolidarlos y aplicar capas de protección críticas antes del despliegue.

### Refresco del Índice
Ejecuta el comando `packwiz refresh`, lo cual genera un hash SHA-256 de **cada uno** de los archivos (mods, configs, scripts) y los lista en el `index.toml`. Esto le informa al launcher final qué ha cambiado para que descargue solo lo necesario.

### Inyección de `preserve = true` (Protección de Jugador)
Si empujamos archivos de configuración constantemente, correríamos el riesgo de sobreescribir los atajos de teclado del jugador, su RAM o sus ajustes de gráficos en cada actualización.

Para evitarlo, `build-pack.ps1` lee el `index.toml` recién generado e inyecta la propiedad `preserve = true` vía Expresiones Regulares en los siguientes archivos clave:
*   `options.txt`
*   `config/embeddium-options.json` *(Implementado recientemente para asegurar que las opciones predeterminadas base del Configurador Gráfico no se borren, pero se apliquen al instalar)*
*   `config/oculus.properties` *(Ídem)*
*   `config/DistantHorizons.toml`
*   `shaderpacks/*.txt`
*   `config/dynamic_fps.json`

**Resultado:** Si el usuario instala el modpack por primera vez, descarga estos archivos vírgenes. Si ya tiene el modpack y ajustó sus controles/gráficos, Packwiz respeta su archivo local ignorando el del servidor, salvando todas sus configuraciones.
