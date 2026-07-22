# 2026UNI — Modpack Privado

Sistema de instalación y actualización automática para el modpack **2026UNI** (Minecraft 1.20.1 + Forge 47.4.16).

## ¿Qué es esto?

Un solo instalador `.exe` que reemplaza el proceso manual de 15+ pasos (Java, launcher, descargas, configuración, IP del server) por:

1. **Instalar una vez** → descargar y ejecutar `2026UNI-Setup.exe`
2. **Jugar siempre** → abrir el acceso directo → Play → las actualizaciones se descargan solas

## Tecnologías

| Componente | Tecnología |
|---|---|
| Launcher | [Prism Launcher](https://prismlauncher.org/) (portátil, embebido) |
| Auto-actualización | [packwiz](https://packwiz.infra.link/) (manifiesto versionado) |
| Hosting del pack | GitHub Pages (este repo) |
| Instalador | [Inno Setup](https://jrsoftware.org/isinfo.php) |
| Java | JRE 21 embebido (el usuario no instala nada) |

## Estructura del proyecto

```
2026UNI/
├── pack/                    # Pack de packwiz (se publica a GitHub Pages)
│   ├── pack.toml            # Manifiesto principal
│   ├── index.toml           # Índice de archivos (generado por packwiz refresh)
│   ├── mods/                # Archivos .pw.toml (metadatos de mods)
│   ├── config/              # Configuración de mods
│   ├── defaultconfigs/      # Configs por defecto
│   ├── resourcepacks/       # Paquetes de texturas
│   ├── shaderpacks/         # Shaders
│   ├── options.txt          # Configuración de Minecraft
│   └── ...                  # Otras carpetas sincronizadas
│
├── instance-template/       # Plantilla de instancia Prism Launcher
│   ├── instance.cfg         # Config de instancia (RAM, Java, pre-launch)
│   ├── mmc-pack.json        # Componentes (MC 1.20.1 + Forge)
│   └── .minecraft/
│       ├── servers.dat      # IP del servidor pre-cargada
│       └── packwiz-installer-bootstrap.jar
│
├── installer/               # Proyecto de Inno Setup
│   ├── setup.iss            # Script del instalador
│   └── redist/              # Binarios redistribuibles
│
├── scripts/                 # Automatización (PowerShell)
│   ├── setup-packwiz.ps1    # Instalar packwiz
│   ├── sync-overrides.ps1   # Sincronizar configs desde instancia real
│   ├── build-pack.ps1       # Validar y refrescar el pack
│   ├── import-from-curseforge.ps1  # Importar mods del manifest
│   ├── add-mod.ps1          # Agregar un mod nuevo
│   └── clean-mods-folder.ps1      # Detectar duplicados/basura
│
├── .github/workflows/
│   └── publish-pack.yml     # CI: publica pack/ a GitHub Pages
│
└── docs/
    ├── MANUAL-AMIGOS.md     # Manual para amigos (1 página)
    └── GUIA-MANTENIMIENTO.md # Guía de mantenimiento para Brian
```

## Cómo funciona la actualización automática

```
Brian agrega/quita un mod
        │
        ▼
    git push (o corre scripts/add-mod.ps1 + push)
        │
        ▼
    GitHub Actions publica el pack a GitHub Pages
        │
        ▼
    Amigo abre 2026UNI → Play
        │
        ▼
    Prism ejecuta packwiz-installer-bootstrap.jar (pre-launch)
        │
        ▼
    Compara local vs remoto → descarga solo lo que cambió
        │
        ▼
    Minecraft abre ya actualizado
```

## Para desarrolladores / mantenimiento

Ver [docs/GUIA-MANTENIMIENTO.md](docs/GUIA-MANTENIMIENTO.md) para instrucciones detalladas de cómo:
- Agregar/quitar mods
- Publicar actualizaciones
- Compilar el instalador
- Hacer pruebas locales

## Versión actual

- **Modpack:** v1.3.0
- **Minecraft:** 1.20.1
- **Forge:** 47.4.16
- **Mods:** ~264

## Licencia

Proyecto privado. Los mods incluidos pertenecen a sus respectivos autores.
