# Funcionamiento de Packwiz en 2026UNI

Este documento detalla el funcionamiento exacto de Packwiz en el ecosistema 2026UNI, la separación de perfiles y la auto-importación de mods que trabajamos recientemente.

---

## 1. Topología de Perfiles (Independencia Estricta)

El modpack está dividido en dos vertientes principales que funcionan como **proyectos aislados** para Packwiz:

*   **Perfil Normal (`pack/`)**: Toma los archivos de la instancia de pruebas `2026UNI`. Contiene todos los mods, incluyendo mods gráficos y pesados.
*   **Perfil Lite (`pack-lite/`)**: Toma los archivos de la instancia de pruebas `2026UNI_Lite`. Es un índice totalmente independiente.

**Regla de Oro:** Packwiz no comparte información entre `pack` y `pack-lite`. Si agregas un mod a la carpeta de la versión Normal, la versión Lite **no** se entera de su existencia mágicamente. Cada perfil tiene su propio archivo `index.toml` y carpeta de mods.

---

## 2. El Manejo de Mods (.pw.toml vs .jar)

Packwiz gestiona los mods de forma inteligente para no llenar el repositorio de Git con archivos pesados.

*   **Archivos gestionados (`.pw.toml`)**: Cuando añades un mod de CurseForge o Modrinth, Packwiz crea un archivo de texto ligero con el hash y la URL de descarga. El launcher del usuario descargará el `.jar` original directamente de la plataforma.
*   **Archivos sueltos (`.jar`)**: Si un mod es propio, un fork, o no existe en plataformas públicas, se guarda directamente como un `.jar` en el repositorio.

---

## 3. El Auto-Importador Dinámico (`auto-import-mods.py`)

Debido a que agregar `.jar` puros al servidor inflaría enormemente el repositorio de GitHub, se utiliza un script en Python que automatiza la conversión de `.jar` a `.pw.toml`.

### ¿Qué soluciona?
Originalmente, si arrastrabas mods nuevos a tu instancia local, tenías que acordarte de añadirlos manualmente vía CLI de Packwiz. Este script hace que eso sea automático.

### Flujo actualizado y Dinámico
Tras las últimas correcciones, el script fue independizado de rutas fijas y funciona así:

1.  **Iteración de Perfiles:** El script principal `publish.ps1` ejecuta este script en Python **dos veces**: una apuntando a `2026UNI\mods` (para actualizar `pack/mods`) y otra apuntando a `2026UNI_Lite\mods` (para actualizar `pack-lite/mods`).
2.  **Identificación Algorítmica:** Escanea cada archivo `.jar`, calcula su hash SHA-1 y hace matching con la API de CurseForge y Modrinth.
3.  **Conversión:** Si las plataformas responden positivamente, el script registra el `.pw.toml` oficial y **borra** el `.jar` bruto, ahorrando memoria.
4.  **Si no se encuentra:** Si el mod no existe en las plataformas (ej. `saintsdragons`), se deja intacto como un `.jar` local y es sincronizado gracias a la lógica añadida en `sync-overrides.ps1`.
