# Guía de Gestión de Configuraciones (Modpack 2026UNI)

Este documento explica cómo funciona la arquitectura de sincronización de configuraciones del instalador. Su objetivo es que el desarrollador pueda actualizar ajustes por defecto sin borrar las personalizaciones de los jugadores (controles, shaders activos, Distant Horizons, etc.).

---

## 1. Opciones de Vanilla (Teclas, Volumen, Gráficos)
El archivo `options.txt` contiene las teclas e idioma del jugador. Si lo sincronizamos directamente, les borraríamos sus controles en cada actualización.

**¿Cómo funciona?**
Se utiliza el mod **Default Options**.
Este mod permite definir configuraciones "base" que los jugadores descargan, pero que se fusionan inteligentemente con sus configuraciones propias.

**Pasos para actualizar teclas/opciones:**
1. Abre tu juego (la instancia del desarrollador).
2. Configura las teclas, volumen, FOV, etc. como quieres que sean las "por defecto".
3. En el chat del juego, escribe el comando: `/defaultoptions saveAll`
4. Esto guardará tu configuración en la carpeta `config/defaultoptions/`.
5. Ejecuta `publicar-actualizacion.bat` como de costumbre.
*(Nunca debes enviar `options.txt` en la raíz del instalador, el script ya lo ignora automáticamente).*

---

## 2. Archivos Físicos (Shaders y ResourcePacks)
Packwiz tiene una regla estricta sobre las carpetas administradas (como `shaderpacks/` y `resourcepacks/`).

**¿Cómo funciona?**
* **Para borrar un shader oficial:** Si tú eliminas `Shader-Oficial.zip` de tu carpeta y publicas, Packwiz se lo borrará a todos los jugadores automáticamente.
* **Para respetar los shaders de los jugadores:** Si un jugador mete su propio `Shader-Pirata.zip`, Packwiz lo **ignora** y no lo borra, porque no está en el índice oficial.

---

## 3. Activación de Shaders (Oculus / Embeddium)
En Forge 1.20.1, saber si los shaders están encendidos o apagados se guarda en el archivo `config/oculus.properties`.
Por defecto, si tú mandas el modpack con los shaders apagados, se los apagarías a todos los jugadores que los hayan encendido.

**¿Cómo funciona?**
El script `build-pack.ps1` tiene una regla mágica: le pone la etiqueta `preserve = true` al archivo `oculus.properties`.
Esto significa que los jugadores descargan tu archivo **solo la primera vez** (empezando con shaders apagados). Si ellos los encienden, el instalador NUNCA MÁS sobreescribirá ese archivo.

### 🔴 ¿Cómo FORZAR el apagado de Shaders para todos?
Si hay un evento y necesitas obligar a que todos reciban tu archivo `oculus.properties` (para apagarles los shaders a la fuerza), sigue estos pasos:

1. Abre el archivo `scripts/build-pack.ps1` en tu editor de código.
2. Busca la sección `$preservePatterns = @(` (alrededor de la línea 74).
3. Borra o comenta la línea que dice: `'file = "config/oculus\.properties"',`
4. Asegúrate de tener los shaders **apagados** en tu juego.
5. Ejecuta `publicar-actualizacion.bat`.
6. Al quitar la protección, el archivo se enviará como obligatorio y sobreescribirá el de todos los jugadores.
7. *(Importante)*: Recuerda volver a poner la línea en el script después de publicar, para devolverles la libertad en futuras actualizaciones.

---

## 4. Distant Horizons y Configuraciones Sensibles
Al igual que los shaders, el mod Distant Horizons guarda su configuración en `config/DistantHorizons.toml`.

**¿Cómo funciona?**
El script `build-pack.ps1` también le pone `preserve = true` a este archivo. 
Se respeta si los jugadores deciden aumentarle los chunks de renderizado o desactivar el mod por completo. 

### 🔴 ¿Cómo FORZAR la configuración de Distant Horizons?
Si descubres un bug crítico o quieres forzar que todos usen la misma distancia de chunks, sigue exactamente los mismos pasos que con Oculus:
1. Abre `scripts/build-pack.ps1`.
2. Borra o comenta la línea `'file = "config/DistantHorizons\.toml"',`
3. Configura el mod a tu gusto en tu juego.
4. Publica la actualización. 
5. Vuelve a colocar la línea en el script para protegerlo nuevamente.

---

## 5. Archivos .txt de los Shaders
Cuando un jugador configura los gráficos internos de un shader (como el color del agua), se crea un archivo de texto con el mismo nombre del shader (ej. `ComplementaryReimagined_r5.6.1.txt`).

**¿Cómo funciona?**
El script aplica automáticamente `preserve = true` a todos los archivos que terminen en `.txt` dentro de la carpeta `shaderpacks/`. Sus configuraciones de iluminación siempre estarán a salvo.
