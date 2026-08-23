# Contexto Arquitectónico: Servidor 2026UNI, Packwiz y Fork de Emojiful

Este documento contiene todo el contexto técnico, flujo de despliegue y detalles de la arquitectura actual del ecosistema del Servidor 2026UNI. Está diseñado para ser leído por un agente de IA para entender completamente el entorno y solucionar problemas.

## 1. Topología del Entorno

El ecosistema se divide en 3 entornos principales alojados en una máquina anfitriona Windows:

- **Servidor de Producción (`C:\Server2026UNI`)**: 
  - Ejecuta Minecraft Forge 1.20.1 (Java JDK 21).
  - Los jugadores se conectan aquí.
  - Los mods del servidor deben coincidir estrictamente con los del cliente.
- **Cliente Madre (`C:\Users\brian\AppData\Roaming\.minecraft\2026UNI`)**: 
  - Entorno de desarrollo y pruebas locales. 
  - Desde aquí nacen las configuraciones y los archivos `.jar` definitivos que luego se empaquetarán.
- **Repositorio de Empaquetado (`C:\Dev\Desarrollo con Inteligencia Artificial\Entorno - Servidor 2026UNI\Instalador 2026UNI`)**:
  - Contiene los scripts de PowerShell (`publish.ps1`, `build-pack.ps1`, `fix-blocked-mods.ps1`) que extraen los archivos del Cliente Madre, los validan y construyen el Modpack usando la herramienta CLI **Packwiz**.
  - Este repositorio hace *push* a GitHub, donde GitHub Actions expone el `pack.toml` mediante GitHub Pages.
- **Launcher Final (PineconeMC)**: 
  - Entorno del usuario final (ej. `C:\Users\brian\AppData\Roaming\.minecraft\2026UNI_Launcher\PineconeMC\instances\2026UNI\.minecraft`).
  - Utiliza un script `pre-launch.bat` que ejecuta `packwiz-installer-bootstrap.jar` conectándose a GitHub Pages para sincronizar su carpeta de mods/config antes de lanzar el juego.

## 2. Cómo funciona Packwiz en este Ecosistema

**Packwiz** es una herramienta de gestión de modpacks que usa hashes (`SHA-256` o `SHA-1`) para determinar si un archivo ha cambiado, se ha añadido o se ha eliminado.

- **Flujo de Publicación (`build-pack.ps1` -> `packwiz refresh`)**:
  - Lee la carpeta del Cliente Madre.
  - Actualiza el archivo `index.toml`, recalculando el hash de todos los archivos `.jar` y `.json`.
  - Si un mod cambia (ej. un recompilado con el mismo código pero distinta firma de bits), su Hash cambia.
- **Flujo de Sincronización del Cliente (`packwiz-installer-bootstrap.jar`)**:
  - Cuando el usuario abre PineconeMC, el instalador descarga el `pack.toml` y el `index.toml` remoto.
  - Compara los hashes del índice remoto con el estado local de su carpeta.
  - **Descargas**: Si hay un hash nuevo, descarga el archivo.
  - **Eliminaciones**: Si un archivo *estaba en un índice anterior (local)* y *ya no está en el índice nuevo*, Packwiz asume que fue eliminado del modpack y **lo elimina de la carpeta del usuario**.
  - **Archivos no rastreados**: Si el usuario metió un `.jar` manual (que jamás estuvo en ningún índice del servidor), Packwiz lo ignora por seguridad (no lo borra).
- **Problema Conocido (Caché de GitHub Pages)**: 
  - GitHub Pages usa un caché de ~10 minutos (`Cache-Control: max-age=600`).
  - Si el modpack se publica e inmediatamente un usuario abre PineconeMC, Packwiz leerá el `index.toml` antiguo (por el caché), y no aplicará ninguna actualización.

## 3. El Fork de Emojiful (4.2.0-custom -> 4.3.0)

**Emojiful** es un mod de Forge 1.20.1 que renderiza emojis dentro del juego. En el proyecto 2026UNI, este mod está forkeado y acoplado fuertemente a las integraciones del servidor.

- **Integraciones del Fork**:
  - Se sincroniza con la página web "Mod Manager".
  - Se sincroniza con Discord a través del "Bot Guardian".
  - El Bot intercepta la sintaxis `:emoji:`, lo renderiza y hace puente entre el chat de Minecraft y Discord.
- **Historial del Problema de Actualización Reciente**:
  1. En la versión `1.8.7` del modpack, existía el archivo `Emojiful-Forge-1.20.1-4.2.0-custom.jar` trackeado en el `index.toml`.
  2. Se recompiló y se subió el mod actualizado con el nombre `Emojiful-Forge-1.20.1-4.3.0.jar` (Versión del modpack `1.9.2`). El script de publicación eliminó el rastro de la `4.2.0-custom` en el nuevo `index.toml` y agregó la `4.3.0`.
  3. El Servidor de Producción se actualizó a la versión `4.3.0`.
  4. Al intentar entrar con el cliente inmediatamente después de publicar, el cliente cargó la `4.2.0-custom` y el servidor rechazó la conexión (Error: *mismatched mod channel list*).
  5. **La Causa Raíz**: Debido al caché de GitHub Pages, el cliente no vio el nuevo `index.toml` de la versión `1.9.2`. Por lo tanto, `packwiz-installer` no corrió ninguna lógica de actualización (ni descargó la 4.3.0 ni ordenó borrar la 4.2.0-custom, que sí hubiera borrado si hubiera leído el índice correcto).

## 4. Reglas Estrictas del Workspace (Para la IA)

- **Aislamiento**: NUNCA sugerir soluciones ni hacer modificaciones directas en el entorno del cliente final (`PineconeMC\instances\2026UNI\.minecraft`). Todo parche, solución de código o test debe fluir **únicamente** modificando el Cliente Madre y corriendo los scripts de publicación automatizada.
- **Sin Cajas Negras**: Toda solución propuesta por la IA debe explicar el mecanismo técnico de fondo (qué archivo se toca, por qué el hash cambia, qué comando exacto de git/packwiz se invoca, etc.).
- **Seguridad**: Especial precaución con la telemetría, `enviar-logs.ps1`, URLs de webhooks y tokens de Discord/API (no exponerlos en texto claro ni sugerir código que pueda exponerlos en logs).
- **Control de Versiones**: Los archivos masivos del servidor NO van en Git. Git es solo para código fuente de mods y configs (JSON, TOML, scripts).
