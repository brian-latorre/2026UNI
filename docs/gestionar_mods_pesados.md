# Gestión de Mods Pesados y Modificados (Alternativa a Git LFS)

## El Problema
Al desarrollar y mantener el instalador 2026UNI, es común necesitar modificar archivos `.jar` de mods directamente (por ejemplo, para eliminar dependencias conflictivas como `tukaani` o `jna` con WinRAR). 

Cuando se modifica un `.jar`, la firma o *hash* cambia. Como resultado, **Packwiz** ya no puede descargarlo desde CurseForge o Modrinth, y el script de automatización (`auto-import-mods.py`) intenta incluir el archivo `.jar` local crudo en el repositorio Git de forma predeterminada.

**Límite de GitHub:** GitHub bloquea permanentemente cualquier intento de hacer `git push` de archivos que superen los **100 MB**. Mods visuales (como `watermedia_binaries` que pesan >140 MB) causan un error silencioso durante la ejecución del script `Publicar-Actualizacion.bat`, deteniendo por completo el despliegue de las actualizaciones a los jugadores.

## La Solución Escalable y Profesional

Para distribuir archivos mayores a 100 MB de forma eficiente y sin saturar el historial de Git, utilizamos la infraestructura de **GitHub Releases** como un servidor de descargas directas para Packwiz.

### Flujo de Trabajo para Actualizar un Mod Pesado (>100MB)

1. **Crear el Mod Localmente:**
   Modifica tu archivo `.jar` (ej. `watermedia_binaries-3.0.0-rc.4.jar`) con tus correcciones y guárdalo en cualquier lugar de tu PC (fuera de la carpeta del proyecto).

2. **Subir el archivo a GitHub Releases:**
   - Ve a la página de [GitHub Releases del Repositorio](https://github.com/brian-latorre/2026UNI/releases).
   - Haz clic en **"Draft a new release"**.
   - Usa un tag descriptivo (por ejemplo `mods-pesados`, `watermedia-fix`).
   - En la caja de "Attach binaries by dropping them here" en la parte inferior, arrastra tu archivo `.jar` modificado. GitHub Releases permite adjuntar archivos de hasta **2 GB**.
   - Publica el release.
   - Una vez publicado, haz clic derecho sobre el enlace del archivo `.jar` subido y selecciona **"Copiar dirección de enlace"**.

3. **Integrar la URL de descarga con Packwiz:**
   - En tu computadora, asegúrate de que el archivo `.jar` pesado que modificaste **NO ESTÉ** dentro de la carpeta `pack/mods/` (si está ahí, bórralo temporalmente para que Git no lo encuentre).
   - Abre una terminal (PowerShell o CMD) dentro de la carpeta `pack/`.
   - Ejecuta el comando `url add` de Packwiz dándole un nombre de identificador y pegando la URL:
     ```cmd
     ..\tools\packwiz.exe url add "nombre-del-mod" "URL_COPIADA"
     ```
     *Ejemplo práctico:* 
     ```cmd
     ..\tools\packwiz.exe url add watermedia-binaries "https://github.com/brian-latorre/2026UNI/releases/download/WATERMEDIA-FIX/watermedia_binaries-3.0.0-rc.4.jar"
     ```

4. **Publicar la Actualización Automatizada:**
   - Una vez ejecutado el comando anterior, Packwiz habrá creado un pequeño archivo de texto `.pw.toml` (que solo pesa unos bytes).
   - Ahora simplemente ejecuta **`Publicar-Actualizacion.bat`** como de costumbre.
   - El script subirá los cambios al código fuente sin problemas, y el launcher de los jugadores se encargará de descargar el mod de 140MB directamente desde los servidores rápidos de GitHub Releases.
