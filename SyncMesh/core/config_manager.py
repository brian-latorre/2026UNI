import json
from pathlib import Path

# Configuración persistente del usuario
CONFIG_FILE = Path(r"C:\Dev\Desarrollo con Inteligencia Artificial\Entorno - Servidor 2026UNI\Instalador 2026UNI\syncmesh_config.json")

def load_config() -> dict:
    if not CONFIG_FILE.exists():
        # Valores por defecto heredados del diseño original
        default_config = {
            "preserved_files": [
                "options.txt",
                "config/oculus.properties",
                "config/DistantHorizons.toml",
                "config/dynamic_fps.json"
            ],
            "ignored_files": [] # Para sobrescribir o forzar overrides no listados en packwizignore
        }
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(default_config, f, indent=4)
        return default_config
        
    with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_config(config: dict):
    with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=4)

def update_file_status(filepath: str, status: str):
    """Actualiza el estado de un archivo en la configuración (preserve, force, ignore)."""
    config = load_config()
    
    # Limpiar estado previo
    if filepath in config.get("preserved_files", []):
        config["preserved_files"].remove(filepath)
    if filepath in config.get("ignored_files", []):
        config["ignored_files"].remove(filepath)
        
    # Asignar nuevo
    if status == "yellow":
        if "preserved_files" not in config: config["preserved_files"] = []
        config["preserved_files"].append(filepath)
    elif status == "red":
        if "ignored_files" not in config: config["ignored_files"] = []
        config["ignored_files"].append(filepath)
    # Si es "green" (Forzar), simplemente se saca de las listas de arriba (comportamiento por defecto)
    
    save_config(config)
