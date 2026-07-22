import os
import sys
import glob
import shutil
import hashlib
import urllib.request
import urllib.error
import json
import subprocess
import time

def hash_sha1(filepath):
    h = hashlib.sha1()
    with open(filepath, 'rb') as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def check_modrinth(sha1_hash):
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
        print(f"    [!] Error consultando Modrinth API: {e.code}")
    except Exception as e:
        print(f"    [!] Error: {e}")
    return None, None

def main():
    appdata = os.environ.get('APPDATA')
    source_mods_dir = os.path.join(appdata, ".minecraft", "2026UNI", "mods")
    
    script_dir = os.path.dirname(os.path.abspath(__file__))
    pack_dir = os.path.abspath(os.path.join(script_dir, "..", "pack"))
    pack_mods_dir = os.path.join(pack_dir, "mods")
    
    packwiz_exe = os.path.abspath(os.path.join(script_dir, "..", "tools", "packwiz.exe"))
    
    if not os.path.exists(source_mods_dir):
        print(f"Error: No se encontró la carpeta mods origen: {source_mods_dir}")
        sys.exit(1)
        
    print(f"============================================")
    print(f"  Auto-Importación Inteligente — 2026UNI")
    print(f"============================================")
    
    # 1. Copiar todos los jars no registrados a pack/mods/
    print("\n[1/4] Copiando mods nuevos al pack...")
    os.makedirs(pack_mods_dir, exist_ok=True)
    
    source_jars = glob.glob(os.path.join(source_mods_dir, "*.jar"))
    copied_count = 0
    for jar in source_jars:
        if jar.endswith(".input") or jar.endswith("-disabled"): continue
        
        jar_name = os.path.basename(jar)
        dest_jar = os.path.join(pack_mods_dir, jar_name)
        
        # Verificar si ya existe un .pw.toml para este mod
        # (Aproximación simple: ver si ya hay metadatos)
        # Para ser seguros, solo copiamos si no hay un .pw.toml con nombre similar
        # Pero es más fácil copiar todo y que packwiz lo resuelva/ignore.
        if not os.path.exists(dest_jar):
            shutil.copy2(jar, dest_jar)
            copied_count += 1
            
    print(f"  Se copiaron {copied_count} .jar(s) para ser evaluados.")
    
    # 2. Detectar con CurseForge
    print("\n[2/4] Detectando mods con CurseForge...")
    try:
        subprocess.run([packwiz_exe, "curseforge", "detect", "-y"], cwd=pack_dir, check=True)
        print("  Detección de CurseForge finalizada.")
    except Exception as e:
        print(f"  [!] Error en curseforge detect: {e}")
        
    # 3. Lo que CurseForge no detectó (quedan como .jar), buscarlo en Modrinth
    print("\n[3/4] Detectando mods restantes con Modrinth...")
    remaining_jars = glob.glob(os.path.join(pack_mods_dir, "*.jar"))
    
    if not remaining_jars:
        print("  No quedaron .jar sin registrar.")
    else:
        print(f"  {len(remaining_jars)} mods restantes por identificar...")
        
        modrinth_found = 0
        for jar in remaining_jars:
            jar_name = os.path.basename(jar)
            print(f"  Analizando: {jar_name}...", end="", flush=True)
            
            sha1 = hash_sha1(jar)
            project_id, version_id = check_modrinth(sha1)
            
            if project_id:
                print(f" OK (Modrinth: {project_id})")
                # Registrar con packwiz
                try:
                    subprocess.run(
                        [packwiz_exe, "modrinth", "add", "--project-id", project_id, "--version-id", version_id, "-y"],
                        cwd=pack_dir, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT
                    )
                    # Si funcionó, borramos el .jar (ahora hay un .pw.toml)
                    os.remove(jar)
                    modrinth_found += 1
                except Exception as e:
                    print(f"\n    [!] Falló al agregar a packwiz: {e}")
            else:
                print(f" NO ENCONTRADO")
                
        print(f"  Modrinth identificó y registró {modrinth_found} mods.")
        
    # 4. Limpieza final y reporte
    print("\n[4/4] Limpiando y refrescando...")
    subprocess.run([packwiz_exe, "refresh"], cwd=pack_dir)
    
    final_jars = glob.glob(os.path.join(pack_mods_dir, "*.jar"))
    pw_tomls = glob.glob(os.path.join(pack_mods_dir, "*.pw.toml"))
    
    print("\n============================================")
    print("  Resumen Final")
    print("============================================")
    print(f"  Mods registrados (auto-actualizables): {len(pw_tomls)}")
    print(f"  Mods locales (sin auto-actualización): {len(final_jars)}")
    
    if final_jars:
        print("\n  Nota: Los mods locales se incluirán en el pack y llegarán a tus amigos,")
        print("  pero no se actualizarán automáticamente porque no están en CF/Modrinth.")
        for jar in final_jars:
            print(f"    - {os.path.basename(jar)}")
            
    print("\n¡Todo listo! El pack está completamente automatizado y sincronizado.")

if __name__ == "__main__":
    main()
