import flet as ft
from pathlib import Path
import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.packwiz_parser import get_overrides_tree
from core.config_manager import update_file_status

class OverridesView(ft.Container):
    def __init__(self):
        super().__init__()
        self.expand = True
        self.padding = 20
        self.pack_dir_normal = r"C:\Dev\Desarrollo con Inteligencia Artificial\Entorno - Servidor 2026UNI\Instalador 2026UNI\pack"
        self.pack_dir_lite = r"C:\Dev\Desarrollo con Inteligencia Artificial\Entorno - Servidor 2026UNI\Instalador 2026UNI\pack-lite"
        self.current_pack_dir = self.pack_dir_normal
        
        self.tree_data = {} # Caché del árbol
        
        # Filtros
        self.pack_selector = ft.Dropdown(
            options=[
                ft.dropdown.Option("normal", "Perfil Madre (pack)"),
                ft.dropdown.Option("lite", "Perfil Lite (pack-lite)")
            ],
            value="normal",
            width=200,
            height=40,
            on_select=self.on_pack_change,
            border_color="#30363D",
            text_size=14
        )
        
        self.search_input = ft.TextField(
            hint_text="Buscar archivo o carpeta...", 
            prefix_icon=ft.Icons.SEARCH, 
            height=40,
            expand=True,
            on_change=self.on_filter_change,
            border_color="#30363D",
            text_size=14
        )
        
        self.filter_color = ft.Dropdown(
            options=[
                ft.dropdown.Option("all", "Todos los colores"),
                ft.dropdown.Option("green", "Verdes (Forzados)"),
                ft.dropdown.Option("yellow", "Amarillos (Preservados)"),
                ft.dropdown.Option("red", "Rojos (Ignorados)"),
            ],
            value="all",
            width=200,
            height=40,
            on_select=self.on_filter_change,
            border_color="#30363D",
            text_size=14
        )
        
        # Contenedor del árbol
        self.tree_container = ft.ListView(expand=True, spacing=2)

        self.content = ft.Column(
            expand=True,
            controls=[
                ft.Row([
                    ft.Column([
                        ft.Text("Overrides del Cliente Madre", size=24, weight=ft.FontWeight.BOLD),
                        ft.Text("Verde: Forza sync | Amarillo: Preserve=True | Rojo: Ignorado", color=ft.Colors.WHITE54, size=12)
                    ], expand=True),
                    ft.ElevatedButton("Escanear", icon=ft.Icons.REFRESH, on_click=self.load_data)
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                ft.Divider(height=10, color="transparent"),
                ft.Row([self.pack_selector, self.search_input, self.filter_color], spacing=10),
                ft.Divider(height=10, color="#30363D"),
                ft.Container(
                    expand=True,
                    border=ft.Border(*[ft.BorderSide(1, "#30363D")]*4),
                    border_radius=10,
                    padding=10,
                    clip_behavior=ft.ClipBehavior.HARD_EDGE,
                    content=self.tree_container
                )
            ]
        )
        
    def did_mount(self):
        self.page.run_task(self.load_data_async)
        
    def load_data(self, e):
        self.page.run_task(self.load_data_async)

    def on_pack_change(self, e):
        if self.pack_selector.value == "lite":
            self.current_pack_dir = self.pack_dir_lite
        else:
            self.current_pack_dir = self.pack_dir_normal
        self.page.run_task(self.load_data_async)

    async def load_data_async(self):
        try:
            self.tree_container.controls.clear()
            self.tree_container.controls.append(ft.ProgressRing())
            self.update()
            
            self.tree_data = get_overrides_tree(self.current_pack_dir)
            self.render_tree()
        except Exception as e:
            self.tree_container.controls.clear()
            self.tree_container.controls.append(ft.Text(f"Error cargando: {e}", color="red"))
            self.update()

    def on_filter_change(self, e):
        self.render_tree()
        
    def render_tree(self):
        try:
            self.tree_container.controls.clear()
            search_query = self.search_input.value.lower() if self.search_input.value else ""
            color_filter = self.filter_color.value
            
            ui_nodes, _ = self.build_tree_ui(self.tree_data, search_query, color_filter)
            
            if not ui_nodes:
                self.tree_container.controls.append(ft.Text("No hay resultados.", color=ft.Colors.WHITE54))
            else:
                self.tree_container.controls.extend(ui_nodes)
                
            self.update()
        except Exception as e:
            self.tree_container.controls.clear()
            self.tree_container.controls.append(ft.Text(f"Error renderizando: {e}", color="red"))
            self.update()
        
    def change_file_state(self, filepath: str, new_state: str):
        # Actualiza persistencia
        update_file_status(filepath, new_state)
        # Recargar para recalcular
        self.page.run_task(self.load_data_async)

    def build_tree_ui(self, tree_data, search_query, color_filter):
        """Construye el UI recursivamente. Retorna (lista_controles, color_heredado)."""
        controls = []
        folder_colors = {"green": 0, "yellow": 0, "red": 0}
        
        # Ordenar: carpetas primero, luego archivos, ambos alfabéticamente
        sorted_items = sorted(
            tree_data.items(), 
            key=lambda x: (0 if x[1]["_type"] == "dir" else 1, x[0].lower())
        )
        
        for name, node in sorted_items:
            if node["_type"] == "dir":
                children_ui, child_colors = self.build_tree_ui(node["children"], search_query, color_filter)
                
                # Sumar colores de hijos
                for c in folder_colors: folder_colors[c] += child_colors[c]
                
                if not children_ui: continue # Ocultar carpetas vacías o filtradas
                
                # Determinar color de la carpeta
                folder_color = ft.Colors.BLUE_300
                if child_colors["yellow"] > 0: folder_color = ft.Colors.YELLOW_400
                elif child_colors["red"] > 0 and child_colors["green"] == 0: folder_color = ft.Colors.RED_400
                elif child_colors["green"] > 0: folder_color = ft.Colors.GREEN_400
                
                exp_tile = ft.ExpansionTile(
                    title=ft.Text(name, weight=ft.FontWeight.BOLD),
                    leading=ft.Icon(ft.Icons.FOLDER, color=folder_color),
                    controls=children_ui,
                    expanded=False, # Por defecto cerradas
                    text_color=ft.Colors.WHITE,
                    icon_color=ft.Colors.WHITE54,
                    collapsed_text_color=ft.Colors.WHITE,
                    collapsed_icon_color=ft.Colors.WHITE54,
                )
                controls.append(exp_tile)
            else:
                status = node["status"]
                path = node["path"]
                
                folder_colors[status] += 1
                
                # Filtros
                if color_filter != "all" and status != color_filter:
                    continue
                if search_query and search_query not in name.lower() and search_query not in path.lower():
                    continue
                
                if status == "green":
                    icon_color = ft.Colors.GREEN_400
                    icon = ft.Icons.SYNC
                    tooltip = "Fuerza Sincronización"
                elif status == "yellow":
                    icon_color = ft.Colors.YELLOW_400
                    icon = ft.Icons.LOCK
                    tooltip = "Preservado (No sobrescribe)"
                else:
                    icon_color = ft.Colors.RED_400
                    icon = ft.Icons.SYNC_DISABLED
                    tooltip = "No Sincronizado (Ignorado)"
                    
                # Menú para cambiar el estado
                popup_menu = ft.PopupMenuButton(
                    icon=ft.Icons.MORE_VERT,
                    tooltip="Cambiar Estado",
                    items=[
                        ft.PopupMenuItem(
                            content=ft.Text("Forzar Sync (Verde)"), 
                            icon=ft.Icons.SYNC, 
                            on_click=lambda e, p=path: self.change_file_state(p, "green")
                        ),
                        ft.PopupMenuItem(
                            content=ft.Text("Preservar (Amarillo)"), 
                            icon=ft.Icons.LOCK, 
                            on_click=lambda e, p=path: self.change_file_state(p, "yellow")
                        ),
                        ft.PopupMenuItem(
                            content=ft.Text("Ignorar (Rojo)"), 
                            icon=ft.Icons.SYNC_DISABLED, 
                            on_click=lambda e, p=path: self.change_file_state(p, "red")
                        ),
                    ]
                )
                    
                list_tile = ft.ListTile(
                    title=ft.Text(name, size=14),
                    subtitle=ft.Text(path, size=11, color=ft.Colors.WHITE54),
                    leading=ft.Icon(icon, color=icon_color, tooltip=tooltip),
                    trailing=popup_menu
                )
                controls.append(list_tile)
                
        return controls, folder_colors
