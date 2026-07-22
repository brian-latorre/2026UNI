# 🛠️ Guía de Mantenimiento — 2026UNI

Guía para Brian sobre cómo mantener, actualizar, y probar el modpack.

---

## Tabla de contenidos
1. [Setup inicial (una vez)](#1-setup-inicial)
2. [Agregar/quitar mods](#2-agregarquitar-mods)
3. [Publicar una actualización](#3-publicar-una-actualización)
4. [Pruebas locales](#4-pruebas-locales)
5. [Compilar el instalador](#5-compilar-el-instalador)
6. [Activar GitHub Pages](#6-activar-github-pages)
7. [Estructura de archivos clave](#7-estructura-de-archivos-clave)

---

## 1. Setup inicial

### Prerequisitos
- Git instalado
- packwiz instalado (correr `.\scripts\setup-packwiz.ps1`)
- Inno Setup instalado (ya lo tienes)
- Tu instancia real en `C:\Users\brian\AppData\Roaming\.minecraft\2026UNI`

### Pasos (solo una vez)

```powershell
# 1. Ir al proyecto
cd "C:\Brian-Vault\Programación\Desarrollo con Inteligencia Artificial\Instalador 2026UNI"

# 2. Instalar packwiz
.\scripts\setup-packwiz.ps1

# 3. Sincronizar configs desde tu instancia real
.\scripts\sync-overrides.ps1

# 4. Limpiar la carpeta de mods (revisar basura)
.\scripts\clean-mods-folder.ps1

# 5. Importar los 70 mods del manifest de CurseForge
.\scripts\import-from-curseforge.ps1

# 6. Agregar los mods que faltan (los de Modrinth y otros)
#    El script anterior genera un reporte en unmatched-mods.txt
#    Para cada mod, correr:
.\scripts\add-mod.ps1 -Name "nombre-del-mod" -Source modrinth
#    o para varios:
.\scripts\add-mod.ps1 -Name "mod1", "mod2", "mod3"

# 7. Refrescar el pack
.\scripts\build-pack.ps1

# 8. Inicializar git y hacer primer push
git init
git add .
git commit -m "feat: setup inicial del modpack 2026UNI v1.3.0"
git remote add origin https://github.com/brian-latorre/2026UNI.git
git push -u origin main
```

### Preparar el instalador

1. **Descargar Prism Launcher portable** (`.zip`, NO el instalador)
   - https://prismlauncher.org/download/ → "Portable (.zip)"
   - Descomprimir en `installer/redist/PrismLauncher/`

2. **Descargar JRE 21** (Adoptium Temurin)
   - https://adoptium.net/temurin/releases/?version=21&package=jre&os=windows&arch=x64
   - Descargar el `.zip`, descomprimir en `installer/redist/jre21/`

3. **VC++ Redist 2022**
   - Descargar `vc_redist.x64.exe` de https://aka.ms/vs/17/release/vc_redist.x64.exe
   - Colocar en `installer/redist/`

4. **packwiz-installer-bootstrap.jar**
   - Ya lo descargaste
   - Colocar en `instance-template/.minecraft/`

5. **servers.dat**
   - Copiar desde tu instancia real:
   ```powershell
   Copy-Item "C:\Users\brian\AppData\Roaming\.minecraft\2026UNI\servers.dat" ".\instance-template\.minecraft\servers.dat"
   ```

---

## 2. Agregar/quitar mods

### Agregar un mod desde Modrinth
```powershell
.\scripts\add-mod.ps1 -Name "nombre-del-mod"
```

### Agregar un mod desde CurseForge
```powershell
.\scripts\add-mod.ps1 -Name "nombre-del-mod" -Source curseforge
```

### Agregar un mod desde URL directa
Para mods que no están en Modrinth ni CurseForge (forks, ediciones privadas):
```powershell
.\scripts\add-mod.ps1 -Url "https://github.com/usuario/mod/releases/download/v1.0/mod.jar"
```

### Quitar un mod
```powershell
cd pack
packwiz remove "nombre-del-mod"
```

### Actualizar un mod existente
```powershell
cd pack
packwiz update "nombre-del-mod"
# o actualizar todos:
packwiz update --all
```

### Después de cualquier cambio
```powershell
.\scripts\build-pack.ps1
```

---

## 3. Publicar una actualización

```powershell
# 1. Hacer los cambios (agregar/quitar mods, editar configs)

# 2. Sincronizar configs si cambiaste algo en tu instancia
.\scripts\sync-overrides.ps1

# 3. Refrescar el pack
.\scripts\build-pack.ps1

# 4. Commit y push
git add .
git commit -m "feat: agregar ModNuevo, quitar ModViejo"
git push

# 5. GitHub Actions publica automáticamente a Pages
# 6. Tus amigos reciben la actualización la próxima vez que den Play
```

### Actualizar el CHANGELOG
Edita `CHANGELOG.md` con los cambios que hiciste. Ejemplo:
```markdown
## [1.4.0] — 2026-08-15

### Agregados
- NuevoMod v2.0 — descripción

### Eliminados
- ModViejo — razón

### Cambiados
- Config de X ajustada para Y
```

---

## 4. Pruebas locales

### Opción A: Servidor local de packwiz (recomendada)

Esto simula lo que verán tus amigos sin necesidad de publicar a GitHub Pages.

```powershell
# Iniciar servidor local
.\scripts\build-pack.ps1 -Serve
# Esto levanta http://localhost:8080/pack.toml
```

Luego, en tu instancia de Prism Launcher:
1. Edita la instancia 2026UNI → Settings → Custom Commands
2. Cambia la URL del pre-launch command a `http://localhost:8080/pack.toml`
3. Dale Play — packwiz descargará desde tu servidor local
4. **¡No olvides volver a cambiar la URL a la de GitHub Pages cuando termines!**

### Opción B: Probar con tu instancia existente

Ya tienes tu instancia en `C:\Users\brian\AppData\Roaming\.minecraft\2026UNI`. Puedes:

1. **Verificar que packwiz-installer funciona:**
   ```powershell
   cd "C:\Users\brian\AppData\Roaming\.minecraft\2026UNI"
   java -jar packwiz-installer-bootstrap.jar http://localhost:8080/pack.toml
   ```
   Esto descarga/actualiza los mods sin abrir Minecraft.

2. **Verificar que el pack se carga correctamente:**
   - Abre tu Minecraft normalmente desde tu instancia existente
   - Si carga sin errores, el pack está bien

### Opción C: Instalación limpia de prueba

Para probar el instalador completo como lo haría un amigo:

1. Compila el instalador (sección 5)
2. Crea una carpeta temporal: `C:\temp\test-2026uni`
3. Ejecuta el instalador y selecciona esa carpeta
4. Abre desde el acceso directo que se creó
5. Verifica que todo funcione
6. Desinstala cuando termines

---

## 5. Compilar el instalador

### Prerequisitos
- Inno Setup instalado (ya lo tienes)
- Todos los redistribuibles descargados (ver sección 1)

### Compilar

**Opción A: Desde la GUI de Inno Setup**
1. Abre `installer/setup.iss` con Inno Setup Compiler
2. Menú Build → Compile
3. El `.exe` se genera en `installer/Output/2026UNI-Setup.exe`

**Opción B: Desde la línea de comandos**
```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" ".\installer\setup.iss"
```

### Distribuir
- Sube `2026UNI-Setup.exe` como Release en GitHub:
  - Ve a tu repo → Releases → Create new release
  - Tag: `v1.3.0`
  - Adjunta el `.exe`
  - Publica
- Manda el link de la Release a tus amigos

---

## 6. Activar GitHub Pages

### En tu repo https://github.com/brian-latorre/2026UNI:

1. Ve a **Settings** → **Pages** (en la barra lateral izquierda)
2. En "Build and deployment":
   - Source: selecciona **"GitHub Actions"**
3. Eso es todo — el workflow `.github/workflows/publish-pack.yml` se encarga del resto
4. Después del primer push, tu pack estará disponible en:
   ```
   https://brian-latorre.github.io/2026UNI/pack.toml
   ```

### Verificar que funciona
Después del primer push, abre en tu navegador:
```
https://brian-latorre.github.io/2026UNI/pack.toml
```
Deberías ver el contenido de tu `pack.toml`.

---

## 7. Estructura de archivos clave

| Archivo | Qué hace | Cuándo se modifica |
|---|---|---|
| `pack/pack.toml` | Manifiesto del pack | Al cambiar versión o metadata |
| `pack/index.toml` | Índice de todos los archivos | Automáticamente con `packwiz refresh` |
| `pack/mods/*.pw.toml` | Metadatos de cada mod | Al agregar/quitar mods |
| `pack/config/` | Configuración de mods | Al editar configs en tu instancia + sync |
| `pack/options.txt` | Config de Minecraft | Al cambiar opciones + sync |
| `instance-template/instance.cfg` | Config de la instancia Prism | Raramente (solo si cambia RAM, Java, URL) |
| `instance-template/mmc-pack.json` | Versiones MC+Forge | Solo si actualizas Forge/MC |
| `installer/setup.iss` | Script del instalador | Al cambiar versión o rutas |
| `.github/workflows/publish-pack.yml` | CI/CD | Raramente |

---

## Flujo de trabajo típico

```
Tu instancia real (.minecraft/2026UNI)
    │
    │  .\scripts\sync-overrides.ps1
    ▼
pack/ (directorio del proyecto)
    │
    │  .\scripts\build-pack.ps1
    ▼
index.toml actualizado
    │
    │  git add . && git commit && git push
    ▼
GitHub Actions → GitHub Pages
    │
    │  (automático, cada vez que dan Play)
    ▼
PCs de tus amigos actualizadas
```

---

*Última actualización: julio 2026*
