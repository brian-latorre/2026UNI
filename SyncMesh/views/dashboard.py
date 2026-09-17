import flet as ft
import os
from pathlib import Path
import sys
import datetime

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.packwiz_parser import get_overrides_tree
from core.metrics import get_instance_last_played, count_instance_mods, get_instance_mods
from core.services import check_services_status, toggle_mod_manager, toggle_bot_guardian

class DashboardView(ft.Container):
    def __init__(self, on_navigate=None):
        super().__init__()
        self.expand = True
        self.padding = 30
        self.on_navigate = on_navigate
        
        self.content = ft.Column([
            ft.Text("Dashboard de Control", size=28, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
            ft.Text("Resumen general del estado de SyncMesh y Packwiz.", color=ft.Colors.WHITE54),
            ft.Divider(height=40, color="#30363D"),
            ft.ProgressRing() # Loading placeholder
        ])

    def did_mount(self):
        self.page.run_task(self.load_dashboard_data)

    async def load_dashboard_data(self):
        # 1. Recolectar datos de Instancias
        madre_mods = count_instance_mods("madre")
        lite_mods = count_instance_mods("lite")
        pinecone_mods = count_instance_mods("pinecone")
        last_played = get_instance_last_played()
        
        # 2. Recolectar datos de Overrides
        pack_dir = r"C:\Dev\Desarrollo con Inteligencia Artificial\Entorno - Servidor 2026UNI\Instalador 2026UNI\pack"
        tree = get_overrides_tree(pack_dir)
        
        green_count = 0
        yellow_count = 0
        red_count = 0
        
        def count_nodes(t):
            nonlocal green_count, yellow_count, red_count
            for _, node in t.items():
                if node["_type"] == "file":
                    st = node["status"]
                    if st == "green": green_count += 1
                    elif st == "yellow": yellow_count += 1
                    else: red_count += 1
                else:
                    count_nodes(node["children"])
        count_nodes(tree)
        
        # 3. Servicios
        services = check_services_status()
        
        # --- Construcción de UI ---
        
        # Tarjetas de Instancias
        def create_instance_card(title, instance_key, mods_count, is_active, compare_to=None):
            subtitle = f"{mods_count} mods cargados"
            if compare_to is not None:
                diff = mods_count - compare_to
                if diff > 0: subtitle += f" (+{diff} vs Pinecone)"
                elif diff < 0: subtitle += f" ({diff} vs Pinecone)"
                else: subtitle += " (= Pinecone)"
                
            return ft.Container(
                content=ft.Column([
                    ft.Row([
                        ft.Icon(ft.Icons.VIDEOGAME_ASSET, color=ft.Colors.GREEN_400 if is_active else ft.Colors.BLUE_300),
                        ft.Text(title, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE)
                    ]),
                    ft.Text(subtitle, color=ft.Colors.WHITE54, size=12)
                ]),
                padding=15, bgcolor="#161B22", border_radius=10, expand=True,
                border=ft.Border(*[ft.BorderSide(1, "#30363D")]*4),
                ink=True,
                tooltip="Haz clic para ver los mods de esta instancia",
                on_click=lambda _: self.show_instance_details(title, instance_key, mods_count, compare_to)
            )

        instances_row = ft.Row([
            create_instance_card("2026UNI (Madre)", "madre", madre_mods, last_played=="madre", compare_to=pinecone_mods),
            create_instance_card("2026UNI_Lite", "lite", lite_mods, last_played=="lite", compare_to=pinecone_mods),
            create_instance_card("PineconeMC (Launcher)", "pinecone", pinecone_mods, last_played=="pinecone")
        ], spacing=15)
        
        # Tarjetas Clickables de Navegación
        nav_row = ft.Row([
            self._create_clickable_stat("Overrides (Forzados)", str(green_count), ft.Icons.SYNC, ft.Colors.GREEN_400, 1),
            self._create_clickable_stat("Overrides (Preservados)", str(yellow_count), ft.Icons.LOCK, ft.Colors.YELLOW_400, 1),
            self._create_clickable_stat("Mods Trackeados (API)", "Ver Galería", ft.Icons.EXTENSION, ft.Colors.BLUE_300, 2),
        ], spacing=15)
        
        # Panel de Servicios
        def create_service_toggle(name, is_running, toggle_func):
            status_text = "Corriendo" if is_running else "Detenido"
            status_color = ft.Colors.GREEN_400 if is_running else ft.Colors.RED_400
            icon = ft.Icons.CHECK_CIRCLE if is_running else ft.Icons.ERROR
            
            return ft.Row([
                ft.Icon(icon, color=status_color),
                ft.Text(name, width=150),
                ft.Text(status_text, color=status_color, width=100),
                ft.ElevatedButton("Iniciar" if not is_running else "Apagar", 
                                  on_click=lambda e: self.toggle_and_refresh(toggle_func, not is_running),
                                  style=ft.ButtonStyle(bgcolor=ft.Colors.BLUE_700 if not is_running else ft.Colors.RED_700))
            ])
            
        services_panel = ft.Container(
            content=ft.Column([
                ft.Text("Estado de Servicios Conectados", size=18, weight=ft.FontWeight.BOLD),
                ft.Divider(height=10, color="transparent"),
                create_service_toggle("Mod Manager (Web)", services["mod_manager"], toggle_mod_manager),
                create_service_toggle("Bot Guardian (Discord)", services["bot_guardian"], toggle_bot_guardian)
            ]),
            padding=20, bgcolor="#161B22", border_radius=10,
            border=ft.Border(*[ft.BorderSide(1, "#30363D")]*4)
        )

        # Git Panel
        git_commits = []
        try:
            import subprocess
            result = subprocess.run(
                ["git", "log", "-n", "3", "--pretty=format:%h - %s (%ar)"], 
                cwd=pack_dir, capture_output=True, text=True
            )
            if result.returncode == 0 and result.stdout:
                for line in result.stdout.split('\n'):
                    git_commits.append(ft.Text(line, size=12, color=ft.Colors.WHITE54, font_family="Consolas"))
        except:
            git_commits = [ft.Text("Git no disponible o repositorio no inicializado.", color=ft.Colors.RED_400)]

        git_panel = ft.Container(
            content=ft.Column([
                ft.Row([
                    ft.Icon(ft.Icons.HISTORY, color=ft.Colors.WHITE),
                    ft.Text("Últimos Commits", size=18, weight=ft.FontWeight.BOLD)
                ]),
                ft.Divider(height=10, color="transparent"),
                *git_commits
            ]),
            padding=20, bgcolor="#161B22", border_radius=10, expand=True,
            border=ft.Border(*[ft.BorderSide(1, "#30363D")]*4)
        )

        self.content = ft.Column([
            ft.Text("Dashboard de Control", size=28, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
            ft.Text("Resumen general del estado de instancias, overrides y servicios.", color=ft.Colors.WHITE54),
            ft.Divider(height=20, color="#30363D"),
            ft.Text("Instancias Locales (Detección automática)", weight=ft.FontWeight.W_500),
            instances_row,
            ft.Divider(height=20, color="transparent"),
            ft.Text("Métricas del Modpack (Haz clic para ver detalles)", weight=ft.FontWeight.W_500),
            nav_row,
            ft.Divider(height=20, color="transparent"),
            ft.Row([services_panel, git_panel], alignment=ft.MainAxisAlignment.START, vertical_alignment=ft.CrossAxisAlignment.START)
        ], scroll=ft.ScrollMode.AUTO)
        
        self.update()

    def _create_clickable_stat(self, title: str, value: str, icon: ft.Icons, color: str, route_index: int):
        return ft.Container(
            content=ft.Column([
                ft.Row([ft.Icon(icon, color=color, size=20), ft.Text(title, color=ft.Colors.WHITE54)], alignment=ft.MainAxisAlignment.START),
                ft.Text(value, size=24, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE)
            ]),
            padding=15, bgcolor="#161B22", border_radius=10, expand=True,
            border=ft.Border(*[ft.BorderSide(1, "#30363D")]*4),
            ink=True,
            on_click=lambda _: self.on_navigate(route_index) if self.on_navigate else None
        )
        
    def show_instance_details(self, title, instance_key, count, compare_to):
        try:
            content_controls = [
                ft.Text(f"Esta instancia tiene {count} mods físicos (.jar) en la carpeta mods.")
            ]
            
            if compare_to is not None:
                content_controls.append(ft.Text(f"Diferencia numérica con PineconeMC: {count - compare_to}"))
                
                # Fetch the actual sets
                from core.metrics import get_instance_mods
                this_mods = get_instance_mods(instance_key)
                pinecone_mods = get_instance_mods("pinecone")
                
                extras = sorted(list(this_mods - pinecone_mods))
                faltantes = sorted(list(pinecone_mods - this_mods))
                
                if extras:
                    content_controls.append(ft.Text("\nMods extra (En esta instancia, NO en Pinecone):", weight=ft.FontWeight.BOLD, color=ft.Colors.GREEN_400))
                    for m in extras:
                        content_controls.append(ft.Text(f"+ {m}", size=12, color=ft.Colors.WHITE70))
                        
                if faltantes:
                    content_controls.append(ft.Text("\nMods faltantes (En Pinecone, NO en esta instancia):", weight=ft.FontWeight.BOLD, color=ft.Colors.RED_400))
                    for m in faltantes:
                        content_controls.append(ft.Text(f"- {m}", size=12, color=ft.Colors.WHITE70))
                        
                if not extras and not faltantes:
                    content_controls.append(ft.Text("\nLos mods físicos están 100% sincronizados con Pinecone!", color=ft.Colors.BLUE_300))
                    
            # Wrap content in a Column inside a Container with scrolling
            content_col = ft.Column(content_controls, scroll=ft.ScrollMode.AUTO)
            
            dlg = ft.AlertDialog(
                title=ft.Text(f"Detalles: {title}"),
                content=ft.Container(content=content_col, width=500, height=350, padding=10),
                actions=[ft.TextButton("Cerrar", on_click=lambda e: self.close_dlg(dlg))]
            )
            self.page.dialog = dlg
            dlg.open = True
            self.page.update()
        except Exception as ex:
            import traceback
            err_str = traceback.format_exc()
            err_dlg = ft.AlertDialog(
                title=ft.Text("Error al abrir detalles"),
                content=ft.Text(f"Ocurri un error:\n{err_str}"),
                actions=[ft.TextButton("Cerrar", on_click=lambda e: self.close_dlg(err_dlg))]
            )
            self.page.dialog = err_dlg
            err_dlg.open = True
            self.page.update()
        
    def close_dlg(self, dlg):
        dlg.open = False
        self.page.update()

    def toggle_and_refresh(self, toggle_func, start):
        toggle_func(start)
        # Refrescar UI después de 2 segundos para dar tiempo a que el SO levante el proceso
        import time
        time.sleep(2)
        self.page.run_task(self.load_dashboard_data)
