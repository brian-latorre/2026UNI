# Errores Conocidos y Soluciones (Troubleshooting)

Este documento contiene un registro de los errores conocidos que pueden ocurrir al jugar o instalar el modpack **2026UNI**, así como sus respectivas soluciones.

## 1. El juego se congela (Loop infinito) al final de la pantalla de carga de Mojang

**Síntoma:** 
Al iniciar el juego, la barra de progreso en la pantalla roja de Mojang llega al 100%, pero el juego se queda congelado indefinidamente y nunca llega al menú principal. No se muestra ningún mensaje de cierre o reporte de error (crash report) de forma inmediata.

**Causas comunes:**
Este error suele estar relacionado con bloqueos (deadlocks) en el hilo de renderizado (Render thread) causados por incompatibilidades de versiones entre **Forge** y alguno de los mods incluidos (típicamente mods relacionados a la interfaz como `fancymenu`, `fancy_entity_renderer` o `jei`).

Durante el desarrollo del modpack, esto ocurrió porque Packwiz estaba configurado para instalar una versión de Forge un poco más antigua (`47.4.16`), pero se actualizaron algunos mods a sus últimas versiones que requerían una versión más reciente de Forge para funcionar correctamente sin congelarse.

**Solución:**
1. Asegurarse de que la versión de Forge definida en el archivo `pack/pack.toml` coincida con la versión más reciente/estable compatible con los mods actualizados.
2. Específicamente, subir la versión de Forge a **`47.4.18`** o superior solucionó el problema con las versiones recientes de JEI y Balm.
3. Si el error persiste, revisar el archivo `logs/debug.log` y buscar cuál fue el último mod registrado justo antes de que el proceso se detenga por completo.

## 2. Archivos `.toml` corruptos (Pantalla congelada temprana)

**Síntoma:**
El juego se queda congelado o se cierra repentinamente y en los registros (`logs/latest.log`) aparece un error parecido a:
`com.electronwill.nightconfig.core.io.ParsingException: Not enough data available`

**Causa:**
El juego se cerró de manera forzada (por un apagón, presionar Alt+F4 demasiado pronto o matar el proceso) justo cuando estaba generando un archivo de configuración para un mod. Esto deja el archivo con un tamaño de 0 bytes (completamente vacío). En el siguiente inicio, el mod no puede leer el archivo porque espera configuraciones válidas pero no encuentra nada, haciendo que todo el proceso colapse.

**Solución:**
1. Ve a la carpeta `config` dentro del directorio `.minecraft` de tu instancia.
2. Identifica cualquier archivo con extensión `.toml` (o `.json`) que pese exactamente **0 bytes**.
3. Elimina ese archivo vacío.
4. Vuelve a iniciar el juego. El mod regenerará automáticamente el archivo con sus valores por defecto y el juego iniciará sin problemas.
