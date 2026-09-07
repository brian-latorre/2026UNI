import flet as ft
import traceback

def main(page: ft.Page):
    try:
        # ==========================
        # 1. CONFIGURACIÓN DE LA VENTANA
        # ==========================
        page.title = "SyncMesh - 2026UNI Deployer"
        page.window.width = 1200
        page.window.height = 800
        page.window.min_width = 900
        page.window.min_height = 600
        
        # Paleta de colores neutra/técnica (estilo Zinc/Slate)
        page.theme_mode = ft.ThemeMode.DARK
        page.bgcolor = "#0E1116"
        
        # Configuramos la fuente (Inter/Roboto base, y Monoespaciada para terminales)
        page.fonts = {
            "Inter": "https://github.com/rsms/inter/raw/master/docs/font-files/Inter-Regular.woff2",
            "JetBrainsMono": "https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/webfonts/JetBrainsMono-Regular.woff2"
        }
        page.theme = ft.Theme(font_family="Inter")

        # ==========================
        # 2. COMPONENTES DE UI (Esqueleto)
        # ==========================
        
        # Cabecera
        header = ft.Container(
            content=ft.Row([
                ft.Icon(icon=ft.Icons.LAYERS, color=ft.Colors.BLUE_300, size=30), 
                ft.Text("SyncMesh", size=24, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE), 
                ft.Text("2026UNI Deployer", size=14, color=ft.Colors.WHITE54, italic=True), 
            ], alignment=ft.MainAxisAlignment.START), 
            padding=20,
            bgcolor="#161B22",
            border=ft.Border(bottom=ft.BorderSide(1, "#30363D"))
        )

        from views import DashboardView, OverridesView, ModsManagerView, PublishView

        # Diccionario de vistas reales
        views_dict = {
            0: DashboardView(),
            1: OverridesView(),
            2: ModsManagerView(),
            3: PublishView()
        }

        # Contenedor dinámico que cambiará su 'content' según el menú
        content_area = ft.Container(
            content=views_dict[0],
            expand=True
        )

        def on_nav_change(e):
            selected_index = e.control.selected_index
            content_area.content = views_dict.get(selected_index, views_dict[0])
            content_area.update()

        # Menú de Navegación Lateral (Dashboard, Sincronización, Mods, Publicar)
        nav_rail = ft.NavigationRail(
            selected_index=0,
            label_type=ft.NavigationRailLabelType.ALL, 
            min_width=100,
            min_extended_width=200,
            group_alignment=-0.9,
            destinations=[
                ft.NavigationRailDestination(icon=ft.Icons.DASHBOARD, selected_icon=ft.Icons.DASHBOARD, label="Dashboard"),
                ft.NavigationRailDestination(icon=ft.Icons.SYNC, selected_icon=ft.Icons.SYNC, label="Overrides"),
                ft.NavigationRailDestination(icon=ft.Icons.EXTENSION, selected_icon=ft.Icons.EXTENSION, label="Mods API"),
                ft.NavigationRailDestination(icon=ft.Icons.PUBLISH, selected_icon=ft.Icons.PUBLISH, label="Publicar"),
            ],
            bgcolor="#0E1116",
            on_change=on_nav_change
        )

        # Layout Principal
        main_layout = ft.Row(
            [
                nav_rail,
                ft.VerticalDivider(width=1, color="#30363D"),
                content_area
            ],
            expand=True,
        )

        # Agregar todo a la página
        page.add(header, main_layout)
    except Exception as e:
        print(f"Error detectado: {e}")
        traceback.print_exc()
        page.add(ft.Text(f"CRASH: {e}", color="red"))
        page.update()

if __name__ == "__main__":
    ft.run(main)
