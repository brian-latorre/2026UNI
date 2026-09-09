import os
import time
import logging
from typing import Dict, Any, Optional
import requests
from requests.exceptions import RequestException, Timeout
from dotenv import load_dotenv

# Configuración segura de logging
logger = logging.getLogger(__name__)

# Cargar variables de entorno
load_dotenv()
CURSEFORGE_API_KEY = os.getenv("CURSEFORGE_API_KEY", "")

# User-Agent estándar para identificarnos correctamente (requerido por las políticas de Modrinth)
USER_AGENT = "2026UNI/ModManager (contacto@ejemplo.com)"

class APIError(Exception):
    """Excepción base para errores de la API. Censura automáticamente las claves sensibles."""
    def __init__(self, message: str):
        # Sanitizar el mensaje para asegurar que no contenga la API key en texto plano
        if CURSEFORGE_API_KEY and CURSEFORGE_API_KEY in message:
            message = message.replace(CURSEFORGE_API_KEY, "[REDACTED_API_KEY]")
        super().__init__(message)

def _safe_request(url: str, headers: Dict[str, str], max_retries: int = 3, timeout: int = 10) -> Optional[Dict[str, Any]]:
    """
    Realiza una petición HTTP GET con manejo de Timeouts y Exponential Backoff.
    Oculta cualquier secreto en los mensajes de error.
    """
    attempt = 0
    while attempt <= max_retries:
        try:
            # Se fija un timeout explícito para evitar bloqueos
            response = requests.get(url, headers=headers, timeout=timeout)
            
            # Manejo de Rate Limit (429)
            if response.status_code == 429:
                attempt += 1
                if attempt > max_retries:
                    raise APIError(f"Rate limit excedido tras {max_retries} intentos en URL: {url}")
                
                # Respetar el header 'Retry-After' si existe, si no, Exponential Backoff
                retry_after_str = response.headers.get("Retry-After")
                retry_after = int(retry_after_str) if retry_after_str and retry_after_str.isdigit() else (2 ** attempt)
                
                logger.warning(f"Rate limit alcanzado (429). Reintentando en {retry_after} segundos...")
                time.sleep(retry_after)
                continue
                
            response.raise_for_status()
            return response.json()
            
        except Timeout:
            attempt += 1
            if attempt > max_retries:
                raise APIError(f"Timeout al conectar con la URL tras {max_retries} intentos.")
            
            backoff_time = 2 ** attempt
            logger.warning(f"Timeout al conectar. Reintentando en {backoff_time} segundos...")
            time.sleep(backoff_time)
            
        except RequestException as e:
            # Capturar cualquier otro error (ej. 404, 500 o fallos de red puros) y sanitizar el mensaje
            raise APIError(f"Error de red al conectar: {str(e)}")
            
    return None

class ModrinthAPI:
    BASE_URL = "https://api.modrinth.com/v2"
    
    @classmethod
    def get_mod(cls, project_id: str) -> Optional[Dict[str, Any]]:
        url = f"{cls.BASE_URL}/project/{project_id}"
        headers = {"User-Agent": USER_AGENT}
        return _safe_request(url, headers)

    @classmethod
    async def get_mod_async(cls, project_id: str) -> Optional[Dict[str, Any]]:
        import asyncio
        return await asyncio.to_thread(cls.get_mod, project_id)

class CurseForgeAPI:
    BASE_URL = "https://api.curseforge.com/v1"
    
    @classmethod
    def get_mod(cls, mod_id: str) -> Optional[Dict[str, Any]]:
        url = f"{cls.BASE_URL}/mods/{mod_id}"
        headers = {
            "Accept": "application/json",
            "x-api-key": CURSEFORGE_API_KEY,
            "User-Agent": USER_AGENT
        }
        return _safe_request(url, headers)

    @classmethod
    async def get_mod_async(cls, mod_id: str) -> Optional[Dict[str, Any]]:
        import asyncio
        return await asyncio.to_thread(cls.get_mod, mod_id)
