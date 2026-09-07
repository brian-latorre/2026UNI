import flet as ft
import os
from pathlib import Path
import sys

# Añadir root para poder importar core
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.packwiz_parser import PRESERVED_FILES, PRESERVE_PATTERNS

class DashboardView(ft.Container):
    def __init__(self):
        super().__init__()
        self.expand = True
        self.padding = 30
        
        # Lógica para contar los mods y overrides en vivo
        pack_dir = Path(r"C:\Dev\Desarrollo con Inteligencia Artificial\Entorno - Servidor 2026UNI\Instalador 2026UNI\pack")
        mods_dir = pack_dir / "mods"
        
        # Conteo Real de Mods
        total_mods = 0
        if mods_dir.exists():
            total_mods = len(list(mods_dir.glob("*.pw.toml")))
            
        # Conteo Real de Overrides Protegidos
        total_protegidos = len(PRESERVED_FILES)
        
        # Tarjetas de Estadísticas Reales
        stats_row = ft.Row([
            self._create_stat_card("Mods Instalados", str(total_mods), ft.Icons.EXTENSION),
            self._create_stat_card("Overrides Protegidos", str(total_protegidos), ft.Icons.SHIELD),
            self._create_stat_card("Estado del Servidor", "Offline", ft.Icons.DNS),
        ], spacing=20)
        
        border_style = ft.Border(
            top=ft.BorderSide(1, "#30363D"), 
            right=ft.BorderSide(1, "#30363D"), 
            bottom=ft.BorderSide(1, "#30363D"), 
            left=ft.BorderSide(1, "#30363D")
        )
        
        self.content = ft.Column([
            ft.Text("Dashboard de Control", size=28, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
            ft.Text("Resumen general del estado de SyncMesh y Packwiz.", color=ft.Colors.WHITE54),
            ft.Divider(height=40, color="#30363D"),
            stats_row,
            ft.Divider(height=40, color="transparent"),
            ft.Container(
                content=ft.Text("Aquí se integrará la validación automática de Git y estado del cliente madre.", color=ft.Colors.WHITE54),
                padding=20,
                bgcolor="#161B22",
                border_radius=10,
                border=border_style
            )
        ])
        
    def _create_stat_card(self, title: str, value: str, icon: ft.Icons):
        border_style = ft.Border(
            top=ft.BorderSide(1, "#30363D"), 
            right=ft.BorderSide(1, "#30363D"), 
            bottom=ft.BorderSide(1, "#30363D"), 
            left=ft.BorderSide(1, "#30363D")
        )
        return ft.Container(
            content=ft.Column([
                ft.Row([ft.Icon(icon, color=ft.Colors.BLUE_300, size=20), ft.Text(title, color=ft.Colors.WHITE54)], alignment=ft.MainAxisAlignment.START),
                ft.Text(value, size=32, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE)
            ]),
            padding=20,
            bgcolor="#161B22",
            border_radius=10,
            border=border_style,
            expand=True
        )
