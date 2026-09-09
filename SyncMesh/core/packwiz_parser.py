import re
from pathlib import Path
import tomllib
import logging
import os
import pathspec

from core.config_manager import load_config

# También preservamos cualquier shaderpack config (*.txt en shaderpacks)
PRESERVE_PATTERNS = [
    re.compile(r"^shaderpacks/.*\.txt$")
]

def should_preserve(filepath: str) -> bool:
    """Verifica si la ruta del archivo coincide con los que deben preservarse leyendo la config persistente."""
    filepath = filepath.replace('\\', '/')
    config = load_config()
    
    if filepath in config.get("preserved_files", []):
        return True
    for pattern in PRESERVE_PATTERNS:
        if pattern.match(filepath):
            return True
    return False

def is_force_ignored(filepath: str) -> bool:
    config = load_config()
    return filepath in config.get("ignored_files", [])

def inject_preserve_directive(index_path: str | Path) -> None:
    index_file = Path(index_path)
    if not index_file.exists():
        logging.error(f"El archivo {index_file} no existe. Ejecuta 'packwiz refresh' primero.")
        return

    with open(index_file, 'r', encoding='utf-8') as f:
        text = f.read()

    # Limpiar directivas existentes para evitar duplicados al inyectar (falla packwiz)
    text = re.sub(r'(?m)^preserve\s*=\s*true\s*\r?\n', '', text)
    
    lines = text.splitlines(keepends=True)
    new_lines = []
    in_target_file_block = False

    for line in lines:
        if line.strip() == "[[files]]":
            in_target_file_block = False
            new_lines.append(line)
            continue
            
        file_match = re.match(r'^file\s*=\s*"([^"]+)"', line.strip())
        if file_match:
            filepath = file_match.group(1)
            if should_preserve(filepath):
                in_target_file_block = True
            new_lines.append(line)
            continue
            
        if in_target_file_block:
            if "hash = " in line or "metafile =" in line:
                new_lines.append('preserve = true\n')
                in_target_file_block = False # Inyectado, no hacerlo de nuevo en el mismo bloque
                
        new_lines.append(line)

    with open(index_file, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
        
    logging.info(f"Directivas 'preserve' inyectadas correctamente en {index_file.name}.")

def verify_toml_integrity(index_path: str | Path) -> bool:
    try:
        with open(index_path, 'rb') as f:
            data = tomllib.load(f)
            for file_entry in data.get('files', []):
                if should_preserve(file_entry.get('file', '')):
                    if not file_entry.get('preserve'):
                        logging.warning(f"Fallo en la inyección para {file_entry['file']}")
                        return False
            return True
    except tomllib.TOMLDecodeError as e:
        logging.error(f"Error de sintaxis TOML tras inyección: {e}")
        return False

def get_overrides_tree(pack_dir: str):
    """
    Escanea la carpeta packwiz (ignorando mods) y retorna una estructura jerárquica
    con los estados (green=sync, yellow=preserve, red=ignored).
    """
    pack_path = Path(pack_dir)
    index_path = pack_path / 'index.toml'
    ignore_path = pack_path / '.packwizignore'
    
    # 1. Leer .packwizignore
    ignore_spec = None
    if ignore_path.exists():
        with open(ignore_path, 'r', encoding='utf-8') as f:
            ignore_spec = pathspec.PathSpec.from_lines('gitwildmatch', f)
            
    # 2. Leer index.toml para saber qué está trackeado y qué es preserve
    tracked_files = {} # path -> is_preserved
    if index_path.exists():
        try:
            with open(index_path, 'rb') as f:
                data = tomllib.load(f)
                for entry in data.get('files', []):
                    path = entry['file'].replace('\\', '/')
                    # Usamos should_preserve como fuente de verdad en vivo, ya que 
                    # el index.toml podría no estar inyectado aún si no se ha refrescado.
                    tracked_files[path] = should_preserve(path)
        except Exception:
            pass
            
    # 3. Construir el árbol leyendo el disco
    tree = {}
    
    # Ignorar estas carpetas para no saturar el UI con el servidor crudo
    SKIP_DIRS = {'.git', 'mods', 'SyncMesh'} 
    
    for root, dirs, files in os.walk(pack_path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith('.')]
        
        rel_root = Path(root).relative_to(pack_path).as_posix()
        if rel_root == '.':
            rel_root = ""
            
        for f in files:
            # Archivos raíz de packwiz que no mostramos en overrides
            if rel_root == "" and f in ['pack.toml', 'index.toml', '.packwizignore']:
                continue
                
            file_path = f"{rel_root}/{f}" if rel_root else f
            
            # Determinar estado
            status = "red" # ignorado por defecto
            
            if is_force_ignored(file_path):
                status = "red"
            elif ignore_spec and ignore_spec.match_file(file_path):
                status = "red"
            elif file_path in tracked_files:
                if tracked_files[file_path]:
                    status = "yellow"
                else:
                    status = "green"
            else:
                # Archivos sueltos que packwiz no trackea por algún motivo pero no están ignorados explícitamente
                status = "red" 
                
            # Insertar en el árbol
            parts = file_path.split('/')
            current_level = tree
            for i, part in enumerate(parts):
                if i == len(parts) - 1:
                    current_level[part] = {"_type": "file", "status": status, "path": file_path}
                else:
                    if part not in current_level:
                        current_level[part] = {"_type": "dir", "children": {}}
                    current_level = current_level[part]["children"]
                    
    return tree

def get_all_mods(pack_dir: str):
    """
    Lee todos los archivos .pw.toml en la carpeta mods/ y extrae sus metadatos.
    """
    mods_dir = Path(pack_dir) / 'mods'
    mods = []
    if not mods_dir.exists():
        return mods
        
    for mod_file in mods_dir.glob('*.pw.toml'):
        try:
            with open(mod_file, 'rb') as f:
                data = tomllib.load(f)
                
            mod_name = data.get('name', mod_file.stem)
            filename = data.get('filename', '')
            
            update_data = data.get('update', {})
            source = "unknown"
            project_id = ""
            
            if 'modrinth' in update_data:
                source = "modrinth"
                project_id = update_data['modrinth'].get('mod-id', '')
            elif 'curseforge' in update_data:
                source = "curseforge"
                project_id = str(update_data['curseforge'].get('project-id', ''))
                
            mods.append({
                "file_id": mod_file.stem,
                "name": mod_name,
                "filename": filename,
                "source": source,
                "project_id": project_id,
                "version": data.get('version', 'unknown')
            })
        except Exception as e:
            logging.error(f"Error parseando mod {mod_file}: {e}")
            
    # Ordenar alfabéticamente
    return sorted(mods, key=lambda x: x['name'].lower())
