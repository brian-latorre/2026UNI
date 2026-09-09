import flet as ft
import asyncio
import os
import sys
import subprocess
from pathlib import Path
import tomllib

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.packwiz_parser import inject_preserve_directive

class PublishView(ft.Container):
    def __init__(self):
        super().__init__()
        self.expand = True
        self.padding = 20
        self.project_dir = r"C:\Dev\Desarrollo con Inteligencia Artificial\Entorno - Servidor 2026UNI"
        self.pack_dir = os.path.join(self.project_dir, "Instalador 2026UNI", "pack")
        
        self.current_version = "1.0.0"
        self.next_version = "1.0.1"
        self._get_versions_from_toml()
        
        # UI Elements: Consola Virtual
        self.console_output = ft.ListView(expand=True, spacing=5, auto_scroll=True)
        self.console_container = ft.Container(
            content=self.console_output, bgcolor=ft.Colors.BLACK87, border_radius=10, padding=15, expand=True,
            border=ft.Border(*[ft.BorderSide(1, ft.Colors.OUTLINE)]*4)
        )
        
        # Entradas de Texto
        self.version_input = ft.TextField(
            label=f"Versión (Actual: {self.current_version})",
            value=self.next_version,
            width=250, border_color="#30363D", text_size=14
        )
        
        self.commit_input = ft.TextField(
            label="Descripción del Cambio (Commit)",
            hint_text="Ej: Actualizados mods de rendimiento",
            expand=True, border_color="#30363D", text_size=14
        )
        
        self.publish_btn = ft.ElevatedButton(
            "Publicar Modpack", icon=ft.Icons.ROCKET_LAUNCH, on_click=self.on_publish_click,
            style=ft.ButtonStyle(color=ft.Colors.WHITE, bgcolor=ft.Colors.BLUE_700, padding=15)
        )
        
        self.progress_ring = ft.ProgressRing(width=20, height=20, visible=False)
        
        self.content = ft.Column([
            ft.Text("Publicación de Modpack", size=24, weight=ft.FontWeight.BOLD),
            ft.Text("Se ejecutará el equivalente a Publicar-Actualizacion.bat pero con control de versión.", size=14, color=ft.Colors.WHITE54),
            ft.Divider(height=20, color="#30363D"),
            ft.Row([self.version_input, self.commit_input], spacing=20),
            ft.Container(height=10),
            ft.Text("Consola de Operaciones", size=16, weight=ft.FontWeight.W_500),
            self.console_container,
            ft.Row([self.publish_btn, self.progress_ring], alignment=ft.MainAxisAlignment.END)
        ])

    def _get_versions_from_toml(self):
        pack_toml = Path(self.pack_dir) / "pack.toml"
        if pack_toml.exists():
            try:
                with open(pack_toml, "rb") as f:
                    data = tomllib.load(f)
                    self.current_version = data.get("version", "1.0.0")
                    
                    # Auto-increment logic
                    parts = self.current_version.split('.')
                    if len(parts) >= 1 and parts[-1].isdigit():
                        parts[-1] = str(int(parts[-1]) + 1)
                        self.next_version = '.'.join(parts)
                    else:
                        self.next_version = self.current_version + "-update"
            except:
                pass

    def log_to_console(self, message: str, is_error: bool = False, is_success: bool = False, is_warning: bool = False):
        color = ft.Colors.WHITE70
        if is_error: color = ft.Colors.RED_400
        elif is_success: color = ft.Colors.GREEN_400
        elif is_warning: color = ft.Colors.AMBER_400
            
        self.console_output.controls.append(ft.Text(f"> {message}", color=color, font_family="Consolas", size=13))
        self.update()

    async def run_cmd(self, cmd: str, cwd: str):
        process = await asyncio.create_subprocess_shell(
            cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT, cwd=cwd,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        )
        
        while True:
            line = await process.stdout.readline()
            if not line:
                break
            text = line.decode('utf-8', errors='ignore').strip()
            if text:
                self.log_to_console(text)
                
        await process.wait()
        return process.returncode

    async def update_pack_version(self, new_version: str):
        # Escribimos temporalmente la versión en pack.toml
        pack_toml = Path(self.pack_dir) / "pack.toml"
        if pack_toml.exists():
            with open(pack_toml, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            for i, line in enumerate(lines):
                if line.startswith("version ="):
                    lines[i] = f'version = "{new_version}"\n'
                    break
            with open(pack_toml, 'w', encoding='utf-8') as f:
                f.writelines(lines)

    async def on_publish_click(self, e):
        commit_msg = self.commit_input.value.strip()
        new_version = self.version_input.value.strip()
        
        if not commit_msg:
            self.commit_input.error_text = "Debes proveer una descripción del cambio."
            self.update()
            return
            
        self.commit_input.error_text = None
        self.publish_btn.disabled = True
        self.progress_ring.visible = True
        self.console_output.controls.clear()
        self.update()
        
        self.log_to_console(f"Iniciando pipeline de publicación (v{new_version})...", is_success=True)
        await self.update_pack_version(new_version)
        
        # --- Fase 1: Inyección de Preserves (Antes de publicar por si acaso) ---
        self.log_to_console("Asegurando configuraciones de Overrides...")
        try:
            inject_preserve_directive(os.path.join(self.pack_dir, "index.toml"))
        except Exception as ex:
            self.log_to_console(f"Advertencia en inyección: {ex}", is_warning=True)
            
        # --- Fase 2: Scripts Nativos ---
        self.log_to_console(f"Ejecutando script de publicación nativo (Perfil All)...")
        # El comando que corre publish.ps1 pasándole los argumentos directamente para que no pregunte en la terminal
        cmd = f'powershell.exe -NonInteractive -ExecutionPolicy Bypass -File ".\\scripts\\publish.ps1" -Perfil All -Version "{new_version}" -CommitMessage "{commit_msg}"'
        
        # Debe correrse dentro de "Instalador 2026UNI"
        code = await self.run_cmd(cmd, cwd=os.path.join(self.project_dir, "Instalador 2026UNI"))
        
        if code != 0:
            self.log_to_console("Ocurrió un error en la publicación.", is_error=True)
        else:
            self.log_to_console("¡El Modpack ha sido publicado correctamente!", is_success=True)
            self.current_version = new_version
            self._get_versions_from_toml()
            self.version_input.value = self.next_version
            self.version_input.label = f"Versión (Actual: {self.current_version})"
            
        self.publish_btn.disabled = False
        self.progress_ring.visible = False
        self.update()
