import ctypes
from ctypes import wintypes
import hashlib
import os
import msvcrt

# ====================================================
# DEFINICIONES ESTRICTAS WIN32 API (Para 64-bits safe)
# ====================================================
kernel32 = ctypes.windll.kernel32

kernel32.CreateFileW.argtypes = [
    wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, 
    wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE
]
kernel32.CreateFileW.restype = wintypes.HANDLE

kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
kernel32.CloseHandle.restype = wintypes.BOOL

# Constantes de Kernel32
GENERIC_READ = 0x80000000
FILE_SHARE_READ = 0x00000001
FILE_SHARE_WRITE = 0x00000002
FILE_SHARE_DELETE = 0x00000004
OPEN_EXISTING = 3
INVALID_HANDLE_VALUE = wintypes.HANDLE(-1).value
FILE_ATTRIBUTE_NORMAL = 0x80

def get_safe_file_hash(file_path: str) -> str:
    """
    Calcula el hash SHA-256 de un archivo en Windows, evadiendo los bloqueos 
    de acceso (File Locks) generados por procesos como Java (Minecraft).
    
    Explicación:
    Python estándar crashea (PermissionError) si Java está leyendo un mod.
    Usamos CreateFileW explícitamente diciendo "FILE_SHARE_READ_WRITE", lo 
    que le dice al Kernel que fuerce el permiso de lectura compartida.
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"El archivo no existe: {file_path}")

    # 1. Abrimos el Handle en Windows sin importar si Minecraft lo está usando
    handle = kernel32.CreateFileW(
        file_path,
        GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        None,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        None
    )

    if handle == INVALID_HANDLE_VALUE:
        error_code = ctypes.GetLastError()
        raise OSError(f"Fallo al abrir archivo con Win32 API. Código: {error_code} - {file_path}")

    try:
        # 2. Convertimos el Handle crudo de Windows a un file_descriptor (fd) de C 
        # para que Python lo entienda.
        fd = msvcrt.open_osfhandle(handle, os.O_RDONLY | os.O_BINARY)
    except Exception as e:
        # Si esto falla (raro, por falta de RAM), cerramos el handle de Windows para evitar fuga de memoria
        kernel32.CloseHandle(handle)
        raise e

    # 3. Al usar `os.fdopen()`, Python toma posesión del Descriptor. 
    # Cuando termine el bloque `with`, Python llamará a .close(), lo cual cerrará el Handle de C 
    # y por ende el Handle de Windows automáticamente. ¡Fuga de memoria evitada!
    sha256 = hashlib.sha256()
    with os.fdopen(fd, 'rb') as f:
        # Leemos en bloques de 8KB para no devorar RAM con archivos .jar grandes
        while chunk := f.read(8192):
            sha256.update(chunk)
            
    return sha256.hexdigest()

if __name__ == "__main__":
    # Prueba rápida unitaria en un archivo crítico de la instalación local
    # (Para ejecutarla independientemente y validar)
    test_file = r"C:\Users\brian\AppData\Roaming\.minecraft\2026UNI\options.txt"
    if os.path.exists(test_file):
        print(f"Hash Seguro de options.txt: {get_safe_file_hash(test_file)}")
    else:
        print("El archivo de prueba no se encontró, pero el módulo está listo.")
