# Redistribuibles para el instalador

Esta carpeta debe contener los binarios necesarios para compilar el instalador `.exe`. **NO se suben a git** (están en `.gitignore`).

## Archivos necesarios

### 1. Prism Launcher (Portable)
- **Carpeta:** `PrismLauncher/`
- **Descarga:** https://prismlauncher.org/download/ → **"Portable (.zip)"** (NO la versión instalable)
- **Instrucciones:** Descomprimir el `.zip` aquí, de modo que quede `PrismLauncher/prismlauncher.exe`

> ⚠️ **IMPORTANTE:** Necesitas la versión **portable** (el `.zip`), NO el instalador `.msi` o `.exe` que instala Prism en Program Files. La versión portable es la que permite embeberlo dentro de nuestro instalador.

### 2. JRE 21 (Adoptium Temurin)
- **Carpeta:** `jre21/`
- **Descarga:** https://adoptium.net/temurin/releases/?version=21&package=jre&os=windows&arch=x64
- **Instrucciones:** Descargar el `.zip` (NO el `.msi`), descomprimir aquí, de modo que quede `jre21/bin/javaw.exe`

> 💡 Si ya tienes JDK 21 instalado, puedes copiar la subcarpeta `jre` de tu JDK. Pero para el instalador que recibirán tus amigos, necesitas el JRE completo aquí.

### 3. VC++ Redistributable 2022
- **Archivo:** `vc_redist.x64.exe`
- **Descarga:** https://aka.ms/vs/17/release/vc_redist.x64.exe
- **Nota:** Prism Launcher 6.0+ lo requiere. El instalador lo instala silenciosamente solo si el PC del amigo no lo tiene.

## Verificación

Después de descargar todo, la estructura debe ser:
```
redist/
├── PrismLauncher/
│   ├── prismlauncher.exe
│   ├── Qt*.dll
│   └── ... (otros archivos de Prism)
├── jre21/
│   ├── bin/
│   │   ├── java.exe
│   │   ├── javaw.exe
│   │   └── ...
│   ├── lib/
│   └── ...
└── vc_redist.x64.exe
```
