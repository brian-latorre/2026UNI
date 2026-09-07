import flet as ft
import asyncio

async def mock_get_mod_info(mod_id: str) -> dict:
    """Simula un retardo de red consultando la API."""
    await asyncio.sleep(1.5)  
    return {
        "id": mod_id,
        "title": f"Mod {mod_id.capitalize()}",
        "description": "Descripción profesional del mod y su impacto en el servidor.",
        "image_url": f"https://picsum.photos/seed/{mod_id}/200/150",
        "author": "2026UNI Team",
        "version": "1.20.1"
    }

class ModCard(ft.Container):
    def __init__(self, mod_id: str):
        super().__init__()
        self.mod_id = mod_id
        
        # Diseño profesional tipo Dashboard Card
        self.bgcolor = "#161B22"
        self.border_radius = 12
        self.padding = 15
        self.alignment = ft.Alignment.CENTER
        
        self.border = ft.Border(
            top=ft.BorderSide(1, "#30363D"), 
            right=ft.BorderSide(1, "#30363D"), 
            bottom=ft.BorderSide(1, "#30363D"), 
            left=ft.BorderSide(1, "#30363D")
        )
        
        # Estado inicial: "Cargando..."
        self.loading_indicator = ft.ProgressRing(width=40, height=40, stroke_width=4)
        self.content = ft.Column(
            controls=[
                self.loading_indicator,
                ft.Container(height=10),
                ft.Text("Obteniendo datos...", color=ft.Colors.WHITE54, size=12)
            ],
            alignment=ft.MainAxisAlignment.CENTER,
            horizontal_alignment=ft.CrossAxisAlignment.CENTER
        )

    def did_mount(self):
        self.page.run_task(self.load_mod_data)

    async def load_mod_data(self):
        try:
            mod_data = await mock_get_mod_info(self.mod_id)
            
            self.content = ft.Column(
                controls=[
                    ft.Image(
                        src=mod_data["image_url"],
                        width=float('inf'),
                        height=120,
                        fit=ft.ImageFit.COVER,
                        border_radius=8,
                    ),
                    ft.Container(height=10),
                    ft.Text(mod_data["title"], size=18, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE, max_lines=1, overflow=ft.TextOverflow.ELLIPSIS),
                    ft.Text(mod_data["author"], size=12, color=ft.Colors.BLUE_300),
                    ft.Container(height=5),
                    ft.Text(mod_data["description"], size=12, color=ft.Colors.WHITE54, max_lines=2, overflow=ft.TextOverflow.ELLIPSIS),
                    ft.Container(expand=True),
                    ft.Row(
                        controls=[
                            ft.Container(
                                content=ft.Text(mod_data["version"], size=10, weight=ft.FontWeight.BOLD),
                                bgcolor="#0E1116",
                                padding=ft.Padding(left=8, top=4, right=8, bottom=4),
                                border_radius=4,
                            ),
                            ft.IconButton(icon=ft.Icons.SETTINGS_OUTLINED, icon_size=20, tooltip="Configurar Mod")
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                    )
                ]
            )
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
        
        # Lista simulada de mods instalados
        self.installed_mods = ["jei", "emojiful-fork", "journeymap", "create", "mousetweaks", "playtime-fix", "sync-keys", "rubidium"]
        
        self.grid = ft.GridView(
            expand=True,
            runs_count=5,
            max_extent=280,
            child_aspect_ratio=0.85,
            spacing=20,
            run_spacing=20,
        )
        
        header = ft.Row(
            controls=[
                ft.Column([
                    ft.Text("Catálogo de Mods", size=28, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
                    ft.Text("Gestiona e inspecciona los mods sincronizados desde el servidor", size=14, color=ft.Colors.WHITE54)
                ]),
                ft.Container(expand=True),
                ft.ElevatedButton("Sincronizar", icon=ft.Icons.SYNC, style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=8)))
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN
        )

        self.content = ft.Column(
            controls=[
                header,
                ft.Divider(height=40, color="#30363D"),
                self.grid
            ],
            expand=True
        )

    def did_mount(self):
        self.load_grid()

    def load_grid(self):
        self.grid.controls.clear()
        for mod_id in self.installed_mods:
            self.grid.controls.append(ModCard(mod_id=mod_id))
        self.update()
