import re
from pathlib import Path
import tomllib
import logging

# Configuración de los archivos que no deben sobrescribirse en el cliente del jugador
PRESERVED_FILES = [
    "options.txt",
    "config/embeddium-options.json",
    "config/oculus.properties",
    "config/DistantHorizons.toml",
    "config/dynamic_fps.json"
]

# También preservamos cualquier shaderpack config (*.txt en shaderpacks)
PRESERVE_PATTERNS = [
    re.compile(r"^shaderpacks/.*\.txt$")
]

def should_preserve(filepath: str) -> bool:
    """Verifica si la ruta del archivo coincide con los que deben preservarse."""
    filepath = filepath.replace('\\', '/')
    if filepath in PRESERVED_FILES:
        return True
    for pattern in PRESERVE_PATTERNS:
        if pattern.match(filepath):
            return True
    return False

def inject_preserve_directive(index_path: str | Path) -> None:
    """
    Inyecta 'preserve = true' en los bloques [[files]] de index.toml que coincidan
    con nuestra lista de protección, de forma segura y sin romper el formato.
    """
    index_file = Path(index_path)
    
    if not index_file.exists():
        logging.error(f"El archivo {index_file} no existe. Ejecuta 'packwiz refresh' primero.")
        return

    # Leer el archivo línea por línea
    with open(index_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    in_target_file_block = False
    file_block_processed = False

    for line in lines:
        # Detectamos el inicio de un bloque [[files]]
        if line.strip() == "[[files]]":
            in_target_file_block = False
            file_block_processed = False
            new_lines.append(line)
            continue
            
        # Buscamos la propiedad 'file' dentro del bloque
        file_match = re.match(r'^file\s*=\s*"([^"]+)"', line.strip())
        if file_match:
            filepath = file_match.group(1)
            if should_preserve(filepath):
                in_target_file_block = True
            new_lines.append(line)
            continue
            
        # Si estamos en un bloque objetivo y encontramos una de las claves de hash/meta,
        # significa que podemos inyectar 'preserve = true' antes o después de ellas.
        # Packwiz siempre añade 'hash', 'hash-format' y 'metafile'.
        if in_target_file_block and not file_block_processed:
            if "hash = " in line or "metafile =" in line:
                # Inyectamos la directiva justo antes de cerrar el bloque
                new_lines.append('preserve = true\n')
                file_block_processed = True
                
        # Evitar inyectar preserve dos veces si el script se corre múltiples veces
        if in_target_file_block and "preserve = true" in line:
            file_block_processed = True 
            
        new_lines.append(line)

    # Sobrescribir el index.toml con las nuevas líneas inyectadas
    with open(index_file, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
        
    logging.info(f"Directivas 'preserve' inyectadas correctamente en {index_file.name}.")

def verify_toml_integrity(index_path: str | Path) -> bool:
    """
    Utiliza la librería estándar tomllib (Python 3.11+) para parsear el TOML resultante
    y verificar que la sintaxis sea perfectamente válida y no hayamos roto nada.
    """
    try:
        with open(index_path, 'rb') as f:
            data = tomllib.load(f)
            # Validar que los archivos marcados como preserve realmente tengan la flag
            for file_entry in data.get('files', []):
                if should_preserve(file_entry.get('file', '')):
                    if not file_entry.get('preserve'):
                        logging.warning(f"Fallo en la inyección para {file_entry['file']}")
                        return False
            return True
    except tomllib.TOMLDecodeError as e:
        logging.error(f"Error de sintaxis TOML tras inyección: {e}")
        return False
