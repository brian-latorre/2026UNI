import psutil
import subprocess
import os

MOD_MANAGER_BAT = r"C:\Dev\Desarrollo con Inteligencia Artificial\Entorno - Servidor 2026UNI\Mod Manager\iniciar_web_y_ngrok.bat"
BOT_GUARDIAN_DIR = r"C:\Server2026UNI\discord_bot"

def is_process_running(keyword: str) -> bool:
    """Intenta detectar si un proceso de node/python está corriendo buscando en la línea de comandos."""
    for proc in psutil.process_iter(['cmdline']):
        try:
            cmdline = proc.info.get('cmdline')
            if cmdline:
                cmd_str = ' '.join(cmdline).lower()
                if keyword.lower() in cmd_str:
                    return True
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    return False

def check_services_status():
    return {
        "mod_manager": is_process_running("Mod Manager") or is_process_running("ngrok"), # Aproximación
        "bot_guardian": is_process_running("discord_bot") # Dependiendo de cómo lo corras (node index.js?)
    }

def toggle_mod_manager(start: bool):
    if start:
        # Abrimos en nueva consola independiente
        subprocess.Popen(f'start "" "{MOD_MANAGER_BAT}"', shell=True)
    else:
        # Para matar ngrok y node, esto es brusco, mejor manejar los procesos adecuadamente si es posible
        os.system("taskkill /F /IM ngrok.exe")
        # matar el node del mod manager es dificil si no conocemos el PID.
        # De momento solo matamos ngrok como prueba.

def toggle_bot_guardian(start: bool):
    if start:
        # Asumiendo que es node index.js
        # subprocess.Popen(f'start "" cmd /k "cd /d {BOT_GUARDIAN_DIR} && node index.js"', shell=True)
        pass
    else:
        # No mataremos node globalmente porque puede ser peligroso.
        pass
