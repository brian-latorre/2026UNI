import flet as ft
import asyncio
import os
import sys
from pathlib import Path

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.apis import ModrinthAPI, CurseForgeAPI
from core.packwiz_parser import get_all_mods
from core.metrics import INSTANCES

class ModCard(ft.Container):
    def __init__(self, mod_data: dict, local_jars: dict):
        super().__init__()
        self.mod_data = mod_data
        self.local_jars = local_jars # {"madre": ["jei-1.20.1.jar", ...], ...}
        
        self.bgcolor = "#161B22"
        self.border_radius = 12
        self.padding = 15
        self.alignment = ft.Alignment.CENTER
        
        self.border = ft.Border(*[ft.BorderSide(1, "#30363D")]*4)
        
        self.content = ft.ProgressRing(width=40, height=40, stroke_width=4)

    def did_mount(self):
        self.page.run_task(self.load_mod_data)

    async def load_mod_data(self):
        try:
            title = self.mod_data["name"]
            version = self.mod_data.get("version", "1.20.1")
            filename = self.mod_data["filename"]
            description = filename
            image_url = None
            author = self.mod_data["source"].capitalize()
            project_id = self.mod_data["project_id"]
            
            # --- Lógica Antifragil (Priorizar Modrinth siempre para evitar 403 de Curseforge) ---
            # Si no es de modrinth, intentamos buscar el slug en modrinth de todas formas
            api_data = None
            
            # 1. Intentar con Modrinth directo si el ID existe
            if self.mod_data["source"] == "modrinth" and project_id:
                try: api_data = await ModrinthAPI.get_mod_async(project_id)
                except: pass
                
            # 2. Si no es Modrinth (o falló), buscamos por Slug aproximado en Modrinth (ej. "Just Enough Items" -> "jei" o "just-enough-items")
            if not api_data:
                slug = self.mod_data["file_id"].replace('_', '-')
                try:
                    api_data = await ModrinthAPI.get_mod_async(slug)
                    if api_data: self.mod_data["source"] = "modrinth" # Lo corregimos!
                except: pass
                
            # 3. Solo si Modrinth falla completamente, intentamos Curseforge si tenemos un ID numérico
            if not api_data and self.mod_data["source"] == "curseforge" and project_id.isdigit():
                try: 
                    api_data = await CurseForgeAPI.get_mod_async(project_id)
                    if api_data and "data" in api_data:
                        api_data = api_data["data"] # normalizar
                except Exception as e:
                    # El error 403 suele saltar aquí si no hay API Key. Lo ignoraremos en UI.
                    pass
            
            # --- Mapeo de datos ---
            if api_data:
                if self.mod_data["source"] == "modrinth":
                    description = api_data.get("description", description)
                    image_url = api_data.get("icon_url", None)
                else:
                    description = api_data.get("summary", description)
                    if api_data.get("logo"): image_url = api_data["logo"].get("thumbnailUrl", None)
                    if api_data.get("authors"): author = api_data["authors"][0].get("name", author)

            # --- Instancias Status ---
            def get_instance_icon(inst_name):
                # Verificamos si el archivo .jar existe en la carpeta mods de esa instancia
                exists = filename in self.local_jars.get(inst_name, [])
                return ft.Container(
                    content=ft.Text(inst_name[0].upper(), size=10, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
                    bgcolor=ft.Colors.GREEN_700 if exists else ft.Colors.RED_700,
                    width=20, height=20, border_radius=4, alignment=ft.Alignment.CENTER,
                    tooltip=f"{'Instalado' if exists else 'Falta'} en {inst_name}"
                )

            instance_indicators = ft.Row([
                get_instance_icon("madre"),
                get_instance_icon("lite"),
                get_instance_icon("pinecone")
            ], spacing=5)

            # Renderizado
            img_control = ft.Image(src=image_url, width=float('inf'), height=120, fit=ft.BoxFit.COVER, border_radius=8) if image_url else ft.Container(bgcolor="#30363D", height=120, width=float('inf'), border_radius=8, content=ft.Icon(ft.Icons.EXTENSION, size=50, color=ft.Colors.WHITE54), alignment=ft.Alignment.CENTER)
            
            self.content = ft.Column([
                img_control,
                ft.Container(height=5),
                ft.Row([
                    ft.Text(title, size=16, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE, expand=True, max_lines=1, overflow=ft.TextOverflow.ELLIPSIS),
                    instance_indicators
                ]),
                ft.Text(author, size=11, color=ft.Colors.BLUE_300, max_lines=1, overflow=ft.TextOverflow.ELLIPSIS),
                ft.Container(height=2),
                ft.Text(description, size=11, color=ft.Colors.WHITE54, max_lines=2, overflow=ft.TextOverflow.ELLIPSIS),
                ft.Container(expand=True),
                ft.Row([
                    ft.Container(content=ft.Text(version, size=10, weight=ft.FontWeight.BOLD), bgcolor="#0E1116", padding=ft.Padding(left=8, top=4, right=8, bottom=4), border_radius=4),
                    ft.Icon(ft.Icons.CHECK_CIRCLE, color=ft.Colors.GREEN_400, size=16, tooltip="Trackeado por Packwiz")
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN)
            ])
            self.alignment = ft.Alignment.TOP_LEFT
            self.update()
        except Exception as e:
            self.content = ft.Text(f"Error: {str(e)}", color=ft.Colors.RED)
            self.update()


class ModsManagerView(ft.Container):
    def __init__(self):
        super().__init__()
        self.expand = True
        self.padding = 30
        
        self.grid = ft.GridView(
            expand=True,
            runs_count=5,
            max_extent=280,
            child_aspect_ratio=0.8,
            spacing=20,
            run_spacing=20,
        )
        
        self.content = ft.Column([
            ft.Row([
                ft.Column([
                    ft.Text("Catálogo y Sincronización de Mods", size=28, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
                    ft.Text("M = Madre | L = Lite | P = PineconeMC. Se intentará buscar siempre en Modrinth primero para evitar 403.", size=14, color=ft.Colors.WHITE54)
                ]),
                ft.Container(expand=True),
                ft.ElevatedButton("Recargar Galería", icon=ft.Icons.SYNC, on_click=self.load_grid)
            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
            ft.Divider(height=20, color="#30363D"),
            self.grid
        ])
        self.pack_dir = r"C:\Dev\Desarrollo con Inteligencia Artificial\Entorno - Servidor 2026UNI\Instalador 2026UNI\pack"

    def did_mount(self):
        self.load_grid(None)

    def load_grid(self, e):
        self.grid.controls.clear()
        self.grid.controls.append(ft.ProgressRing())
        self.update()
        
        all_mods = get_all_mods(self.pack_dir)
        
        # Pre-cargar listas de archivos .jar en cada instancia para no hacer IO por cada tarjeta
        local_jars = {}
        for inst_name, inst_path in INSTANCES.items():
            mods_path = Path(inst_path) / "mods"
            if mods_path.exists():
                local_jars[inst_name] = [f.name for f in mods_path.glob("*.jar")]
            else:
                local_jars[inst_name] = []
        
        self.grid.controls.clear()
        display_mods = all_mods[:60] # Límite temporal
        for mod_data in display_mods:
            self.grid.controls.append(ModCard(mod_data=mod_data, local_jars=local_jars))
            
        self.update()
