import os
from pathlib import Path

INSTANCES = {
    "madre": r"C:\Users\brian\AppData\Roaming\.minecraft\2026UNI",
    "lite": r"C:\Users\brian\AppData\Roaming\.minecraft\2026UNI_Lite",
    "pinecone": r"C:\Users\brian\AppData\Roaming\.minecraft\2026UNI_Launcher\PineconeMC\instances\2026UNI\.minecraft"
}

def get_instance_last_played():
    """Retorna un diccionario indicando qué instancia se jugó más recientemente basándose en latest.log"""
    latest_times = {}
    for name, path in INSTANCES.items():
        log_path = Path(path) / "logs" / "latest.log"
        if log_path.exists():
            latest_times[name] = os.path.getmtime(log_path)
        else:
            latest_times[name] = 0
            
    # Ordenar por tiempo (el mayor es el más reciente)
    if not any(latest_times.values()):
        return "madre" # Default
        
    return max(latest_times, key=latest_times.get)

def count_instance_mods(instance_name: str) -> int:
    path = INSTANCES.get(instance_name)
    if not path: return 0
    mods_dir = Path(path) / "mods"
    if not mods_dir.exists(): return 0
    
    return len([f for f in mods_dir.glob("*.jar")])
