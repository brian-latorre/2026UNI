import os
import sys
import glob
import shutil
import hashlib
import urllib.request
import urllib.error
import json
import subprocess
import logging
import datetime
import re

def hash_sha1(filepath):
    h = hashlib.sha1()
    with open(filepath, 'rb') as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def check_modrinth(sha1_hash, logger):
    url = f"https://api.modrinth.com/v2/version_file/{sha1_hash}?algorithm=sha1"
    req = urllib.request.Request(url, headers={'User-Agent': '2026UNI-Setup (brian-latorre)'})
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                return data.get('project_id'), data.get('id')
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None, None
        logger.error(f"Error consultando Modrinth API: {e.code}")
    except Exception as e:
        logger.error(f"Error: {e}")
    return None, None

def setup_logger(project_root):
    logs_dir = os.path.join(project_root, "logs")
    os.makedirs(logs_dir, exist_ok=True)
    
    latest_log = os.path.join(logs_dir, "latest.log")
    if os.path.exists(latest_log):
        try:
            mtime = os.path.getmtime(latest_log)
            dt = datetime.datetime.fromtimestamp(mtime)
            old_name = dt.strftime("%Y-%m-%d-%H-%M-%S.log")
            old_path = os.path.join(logs_dir, old_name)
            counter = 1
            while os.path.exists(old_path):
                old_name = dt.strftime("%Y-%m-%d-%H-%M-%S") + f"-{counter}.log"
                old_path = os.path.join(logs_dir, old_name)
                counter += 1
            os.rename(latest_log, old_path)
        except Exception:
            pass

    old_log = os.path.join(project_root, "pack", "auto-import.log")
    if os.path.exists(old_log):
        try: os.remove(old_log)
        except: pass

    logger = logging.getLogger("AutoImport")
    logger.setLevel(logging.INFO)
    
    formatter = logging.Formatter('%(asctime)s | %(levelname)s | %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
    
    fh = logging.FileHandler(latest_log, encoding='utf-8')
    fh.setFormatter(formatter)
    
    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(formatter)
    
    if not logger.handlers:
        logger.addHandler(fh)
        logger.addHandler(ch)
    
    return logger

def get_expected_jar_name(pw_toml_path):
    try:
        with open(pw_toml_path, 'r', encoding='utf-8') as f:
            content = f.read()
            match = re.search(r'filename\s*=\s*"([^"]+)"', content)
            if match:
                return match.group(1)
    except Exception:
        pass
    filename = os.path.basename(pw_toml_path)
    return filename[:-8] + ".jar" if filename.endswith(".pw.toml") else filename

def main():
    appdata = os.environ.get('APPDATA')
    source_mods_dir = os.path.join(appdata, ".minecraft", "2026UNI", "mods")
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, ".."))
    pack_dir = os.path.join(project_root, "pack")
    pack_mods_dir = os.path.join(pack_dir, "mods")
    
    os.makedirs(pack_mods_dir, exist_ok=True)
    logger = setup_logger(project_root)
    
    packwiz_exe = os.path.abspath(os.path.join(script_dir, "..", "tools", "packwiz.exe"))
    
    if not os.path.exists(source_mods_dir):
        logger.error(f"No se encontró la carpeta mods origen: {source_mods_dir}")
        sys.exit(1)
        
    logger.info("============================================")
    logger.info("  Auto-Importación Inteligente — 2026UNI")
    logger.info("============================================")
    
    # 0. Sincronizar eliminaciones
    logger.info("[0/4] Sincronizando mods eliminados...")
    deleted_count = 0
    pack_files_initial = glob.glob(os.path.join(pack_mods_dir, "*.pw.toml")) + glob.glob(os.path.join(pack_mods_dir, "*.jar"))
    
    for pack_file in pack_files_initial:
        filename = os.path.basename(pack_file)
        
        if filename.endswith(".pw.toml"):
            expected_jar = get_expected_jar_name(pack_file)
        else:
            expected_jar = filename
            
        local_jar_path = os.path.join(source_mods_dir, expected_jar)
        
        if not os.path.exists(local_jar_path):
            os.remove(pack_file)
            deleted_count += 1
            logger.info(f"Mod eliminado detectado y borrado del instalador: {filename} (esperaba {expected_jar})")
            
    if deleted_count > 0:
        logger.info(f"Se eliminaron {deleted_count} mods del instalador.")
    else:
        logger.info("No se detectaron mods eliminados.")
    
    # 1. Copiar JARS nuevos
    logger.info("[1/4] Analizando e importando mods locales...")
    
    # Escaneo en tiempo real después de las eliminaciones del Paso 0
    current_pack_files = glob.glob(os.path.join(pack_mods_dir, "*.pw.toml")) + glob.glob(os.path.join(pack_mods_dir, "*.jar"))
    
    tracked_jars = set()
    for pack_file in current_pack_files:
        if pack_file.endswith(".pw.toml"):
            tracked_jars.add(get_expected_jar_name(pack_file))
        else:
            tracked_jars.add(os.path.basename(pack_file))
    
    source_jars = glob.glob(os.path.join(source_mods_dir, "*.jar"))
    copied_count = 0
    for jar in source_jars:
        if jar.endswith(".input") or jar.endswith("-disabled"): continue
        
        jar_name = os.path.basename(jar)
        
        if jar_name in tracked_jars:
            continue
            
        dest_jar = os.path.join(pack_mods_dir, jar_name)
        if not os.path.exists(dest_jar):
            shutil.copy2(jar, dest_jar)
            copied_count += 1
            logger.info(f"Nuevo mod detectado y copiado: {jar_name}")
            
    logger.info(f"Se copiaron {copied_count} .jar(s) nuevos para ser evaluados por Packwiz.")
    
    # 2. Detectar con CurseForge
    logger.info("[2/4] Detectando mods con CurseForge...")
    if copied_count > 0:
        try:
            result = subprocess.run([packwiz_exe, "curseforge", "detect", "-y"], cwd=pack_dir, capture_output=True, text=True)
            if result.stdout:
                for line in result.stdout.splitlines():
                    if line.strip(): logger.info(f"CurseForge: {line.strip()}")
            if result.stderr:
                for line in result.stderr.splitlines():
                    if line.strip(): logger.warning(f"CurseForge: {line.strip()}")
        except Exception as e:
            logger.error(f"Error en curseforge detect: {e}")
    logger.info("Detección de CurseForge finalizada.")
        
    # 3. Detectar con Modrinth
    logger.info("[3/4] Detectando mods restantes con Modrinth...")
    remaining_jars = glob.glob(os.path.join(pack_mods_dir, "*.jar"))
    
    if not remaining_jars:
        logger.info("No quedaron .jar sin registrar.")
    else:
        logger.info(f"{len(remaining_jars)} mods restantes por identificar en Modrinth...")
        
        modrinth_found = 0
        for jar in remaining_jars:
            jar_name = os.path.basename(jar)
            
            # Solo procesar Jars que no estuvieran ya trackeados previamente como mods locales puros
            if jar_name in tracked_jars:
                continue
                
            logger.info(f"Buscando en Modrinth: {jar_name}...")
            
            sha1 = hash_sha1(jar)
            project_id, version_id = check_modrinth(sha1, logger)
            
            if project_id:
                logger.info(f"-> Mod encontrado en Modrinth (Project ID: {project_id})")
                try:
                    result = subprocess.run(
                        [packwiz_exe, "modrinth", "add", "--project-id", project_id, "--version-id", version_id, "-y"],
                        cwd=pack_dir, capture_output=True, text=True
                    )
                    if result.returncode == 0:
                        os.remove(jar)
                        modrinth_found += 1
                        logger.info(f"-> Registrado exitosamente en packwiz: {jar_name}")
                    else:
                        logger.error(f"-> Falló al agregar a packwiz: {result.stderr or result.stdout}")
                except Exception as e:
                    logger.error(f"-> Excepción al agregar a packwiz: {e}")
            else:
                logger.info(f"-> No encontrado en Modrinth. Se mantendrá como mod local: {jar_name}")
                
        logger.info(f"Modrinth identificó y registró {modrinth_found} mods.")
        
    # 4. Limpieza final y reporte
    logger.info("[4/4] Limpiando y refrescando índice de Packwiz...")
    subprocess.run([packwiz_exe, "refresh"], cwd=pack_dir, capture_output=True)
    
    final_jars = glob.glob(os.path.join(pack_mods_dir, "*.jar"))
    pw_tomls = glob.glob(os.path.join(pack_mods_dir, "*.pw.toml"))
    
    logger.info("============================================")
    logger.info("  Resumen Final")
    logger.info("============================================")
    logger.info(f"Mods registrados (auto-actualizables): {len(pw_tomls)}")
    logger.info(f"Mods locales (sin auto-actualización): {len(final_jars)}")
    
    logger.info("¡Todo listo! El pack está completamente automatizado y sincronizado.")

if __name__ == "__main__":
    main()