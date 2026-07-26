# Documentación Técnica: Ecosistema de Actualización y Mantenimiento (2026UNI)

Este documento detalla exhaustivamente la arquitectura técnica detrás del instalador, el gestor de actualizaciones (Packwiz), la herramienta de reparación y el flujo de publicación del modpack **2026UNI**. Sirve como manual de referencia para comprender el flujo de datos, la persistencia de archivos y la gestión de mods a nivel administrativo.

---

## 1. El Instalador Base (`setup.iss`) y Entorno Aislado

El objetivo del instalador no es solo copiar archivos, sino asegurar un entorno de ejecución **determinista y unificado** para todos los jugadores, evitando problemas clásicos como "tengo una versión incorrecta de Java" o "el launcher me crashea".

### Componentes que se instalan:
1. **Prism Launcher (Portable):** Se extrae una versión portable para no interferir con las instalaciones base de Minecraft del usuario (como el `.minecraft` estándar en `%APPDATA%`).
2. **Java JRE 21:** Se incluye directamente. El instalador vincula Prism Launcher a este ejecutable específico.
3. **Instancia `2026UNI`:** Se crea un perfil (instancia) inyectado con optimizaciones críticas.

### El Comando de Pre-Lanzamiento (`PreLaunchCommand`)
La clave de la sincronización ocurre en la configuración de la instancia (`instance.cfg`), donde se inyecta la siguiente orden:
```ini
PreLaunchCommand=$INST_JAVA -jar $INST_MC_DIR/packwiz-installer-bootstrap.jar https://brian-latorre.github.io/2026UNI/pack.toml
```
**¿Qué hace esto?** 
Asegura que cada vez que el jugador haga clic en "Jugar", Prism Launcher *pause* el inicio de Minecraft y primero ejecute el actualizador (Packwiz). Hasta que Packwiz no termine de sincronizar y verificar los mods, Minecraft no se abre.

---

## 2. Flujo de Datos y Sincronización (Packwiz)

Packwiz es un gestor de modpacks basado en línea de comandos que sincroniza el cliente local del jugador con el servidor remoto (GitHub) a través de comprobaciones criptográficas.

### ¿Qué envía y qué recibe la computadora?
**El flujo es estrictamente de descarga (GET)**. La computadora del jugador jamás envía archivos al repositorio; actúa como un cliente "tonto" que pregunta al servidor: *"¿Cuál es la verdad absoluta?"*

El proceso paso a paso es:
1. **Petición GET:** Packwiz lee el archivo remoto `pack.toml` y el índice principal (`index.toml`) desde GitHub.
2. **Historial Local (`packwiz.json`):** Packwiz consulta este archivo oculto en la computadora del jugador. Es su "diario de memoria", donde anota todos los archivos que ha descargado y gestionado en el pasado.
3. **Validación de Hashes SHA256:** Por cada mod y archivo en el índice remoto, Packwiz escanea el archivo equivalente en el disco del jugador y calcula su firma criptográfica (hash).
4. **Ejecución de Diferencias:** Si el hash de un archivo local es distinto al de GitHub, o si el archivo no existe, Packwiz descarga la versión del servidor.

---

## 3. Comportamiento del Directorio: ¿Qué se sobrescribe y qué se respeta?

Packwiz solo tiene jurisdicción sobre los archivos explícitamente declarados en su repositorio.

| Tipo de Carpeta | Ejemplos | Comportamiento |
| :--- | :--- | :--- |
| **Rastreadas (Modificadas)** | `mods/`, `config/`, `defaultoptions/` | Packwiz tiene el control absoluto. Si el jugador modifica algo aquí, será sobrescrito en el próximo inicio. |
| **No Rastreadas (Ignoradas)** | `options.txt` (raíz), `shaderpacks/`, `resourcepacks/`, `saves/` | Al no estar en el índice de GitHub, Packwiz las ignora. El jugador puede meter sus texturas, shaders o mundos y jamás se le borrarán. |

### Cambios Locales (Por parte del jugador)
- **Modificar un config rastreado:** Si el jugador abre el `config` de un mod y cambia un valor, su hash local cambia. Al iniciar el juego, Packwiz detectará la diferencia y volverá a descargar el archivo oficial, **borrando los cambios del jugador**.
- **Añadir un mod no oficial:** Si el jugador pone "Minimapa.jar" en la carpeta `mods/`, Packwiz simplemente lo ignora y lo deja ahí (porque no figura en GitHub). *Nota: Si este mod externo crashea el juego, Packwiz no lo eliminará automáticamente.*

---

## 4. El Mod DefaultOptions: Gestionando Controles sin Pisarlos

Al saber que Packwiz sobrescribe todo lo que rastrea, surge un problema: ¿Cómo actualizamos los controles (teclas) o las configuraciones de video globales sin sobrescribir el archivo `options.txt` del jugador (y arruinarle sus teclas personalizadas cada vez que juega)?

**La solución es `DefaultOptions`:**
1. Tú (Administrador) configuras el juego y guardas los controles en la carpeta `defaultoptions/`.
2. Subes esa carpeta a GitHub. Packwiz rastrea esta carpeta, asegurando que todos los jugadores tengan siempre tus archivos `defaultoptions` actualizados.
3. **Al arrancar Minecraft:** El mod *DefaultOptions* toma el relevo. Lee la carpeta `defaultoptions/` y aplica esos controles al archivo `options.txt` raíz **únicamente si es la primera vez que el jugador inicia el juego, o si detecta que has forzado una nueva versión de teclas**.
4. De este modo, el jugador conserva su `options.txt` personalizado y Packwiz no se lo rompe.

---

## 5. Casos Reales de Administración (Ciclo de Vida de un Mod)

Como administrador, tú alteras el estado usando la CLI de Packwiz o tu entorno de desarrollo. Veamos cómo reacciona el cliente.

### Caso A: Actualizar un Mod (Ej: Actualizar `punchy` a v2.6)
**Tu Acción:**
Actualizas el mod localmente (ej: `packwiz update punchy`). Esto genera un nuevo hash para `punchy` en tu archivo `index.toml`. Subes el cambio a GitHub.

**Lo que ocurre en la PC del jugador:**
1. Al dar "Jugar", Packwiz baja el nuevo índice y ve que el hash de `punchy` ya no es el de la versión 2.5, sino el de la 2.6.
2. Al revisar su disco, el jugador tiene el hash viejo.
3. Packwiz **elimina** el `.jar` viejo y **descarga** la versión 2.6.
4. Actualiza su `packwiz.json` local para recordar que ahora tiene la 2.6.

### Caso B: Eliminar un Mod (Ej: Quitar `inspectability`)
**Tu Acción:**
Ejecutas `packwiz remove inspectability`. El mod desaparece por completo del índice y subes los cambios.

**Lo que ocurre en la PC del jugador:**
1. Packwiz baja el índice de GitHub y ve que `inspectability` ya no está en la lista de mods requeridos.
2. Sin embargo, revisa su diario local (`packwiz.json`) y se da cuenta de que *él mismo lo descargó e instaló en el pasado*.
3. Deducción lógica: "Si yo lo instalé y ya no está en el servidor, significa que el administrador lo removió".
4. Packwiz procede a **borrar físicamente el `.jar` de `inspectability`** de la carpeta `mods/` y lo tacha de su `packwiz.json`.

---

## 6. La Herramienta de Reparación (`Reparar Juego.bat`)

El script de reparación funciona como un "Hard Reset" para el cliente sin borrar el juego entero.
Los pasos que realiza son:
1. Borra `options.txt` para resetear controles y video corruptos.
2. Borra la carpeta `config/` para eliminar archivos malformados.
3. **La línea crítica: `del packwiz.json`**. 

**¿Por qué borrar `packwiz.json` es la clave?**
Al borrar este archivo, Packwiz pierde su memoria (el historial de lo que ha instalado). En el próximo arranque, creerá que es una instalación completamente limpia. Como resultado, procederá a verificar y forzar la descarga de absolutamente **todos** los mods y archivos de configuración presentes en GitHub, reparando cualquier archivo faltante o corrupto de raíz.

> **Seguridad Anti-Infiltrados:** Originalmente, Packwiz ignoraba los mods no rastreados (piratas o externos). Para solucionar esto y evitar crasheos por incompatibilidad, el script de reparación también **borra por completo la carpeta `mods/` local**. De esta forma, garantiza que al descargar nuevamente, el jugador tenga una carpeta de mods 100% pura y oficial.

---

## 7. El Automatizador de Publicación (`publicar-actualizacion.bat`)

Esta herramienta (junto con sus scripts subyacentes como `publish.ps1` y `auto-import-mods.py`) es el puente entre el desarrollador del modpack y los jugadores. Transforma un proceso complejo en un "1-Click Update" (Actualización de un solo clic).

El proceso de este script se divide en 4 pasos críticos:

1. **Sincronización de Overrides (`sync-overrides.ps1`):**
   Garantiza que cualquier archivo suelto, script local o imagen que hayas añadido a la carpeta del modpack se empaquete y registre correctamente en la lista de dependencias que subirá.

2. **Auto-Detección e Importación de Mods (`auto-import-mods.py`):**
   Este paso hace magia analizando la carpeta local `mods/`. Se encarga de traducir tus acciones locales a comandos para la nube de forma sumamente inteligente:
   - **Si actualizas un mod:** Entras a tu carpeta, borras el `.jar` viejo y metes el nuevo. El script nota que eliminaste el viejo, lo saca de la nube, y usa la API de CurseForge/Modrinth para detectar el nuevo, registrar su link oficial y subirlo.
   - **Si quitas un mod:** Simplemente borras el `.jar` de tu computadora. Al ejecutar el `.bat`, el script se da cuenta de que falta el archivo físico y automáticamente le ordena a Packwiz: *"Elimina este mod de la lista oficial del servidor"*.
   - **Si añades un mod:** Echas el `.jar` nuevo; el script busca sus datos oficiales, lo registra y asegura que Packwiz pueda auto-descargarlo.
   *Resultado:* Nunca tienes que escribir URLs ni comandos a mano. Tú gestionas tu carpeta `mods/` arrastrando y borrando archivos como si fuera un Minecraft normal, y el `.bat` se encarga de reflejar todos tus movimientos exactos en la nube.

3. **Compilación y Validación del Pack (`build-pack.ps1`):**
   Reconstruye el archivo central `index.toml`. Este archivo es el "índice maestro" del que hablamos en el **Paso 2**. Calcula los nuevos hashes SHA256 de todos tus cambios (configs editados, mods actualizados) y actualiza el índice para que las computadoras de los jugadores sepan exactamente qué descargar para estar sincronizadas contigo. También verifica que no hayas metido mods de versiones incompatibles (ej. mezclar 1.20 con 1.19).

4. **Despliegue a la Nube (Git Push):**
   El script toma el mensaje de "Commit" que ingresaste (ej: *"Actualización del modpack"*), empaqueta el índice actualizado, y lo envía ("push") a la rama principal (`origin main`) de tu repositorio de GitHub. 

**Flujo Completo:** En el momento exacto en que este script termina de ejecutarse y cierra su ventana, tu repositorio de GitHub se actualiza. A partir de ese mismo segundo, cualquier jugador en el mundo que presione el botón de "Jugar" en su Prism Launcher disparará el sistema Packwiz (ver sección 2), leerá tu nuevo `index.toml`, y se actualizará automáticamente con todo el trabajo que acabas de publicar.
