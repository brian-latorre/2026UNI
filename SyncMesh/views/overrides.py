import flet as ft
from pathlib import Path
import sys
import os

# Importación de la lógica de análisis del modpack
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from core.packwiz_parser import PRESERVED_FILES

def get_overrides():
    return [{"filename": f, "path": f, "preserve": True} for f in PRESERVED_FILES]

class OverridesView(ft.Container):
    """
    Vista principal para gestionar los overrides de Packwiz.
    Permite visualizar qué archivos se conservarán (preserve = true) durante las actualizaciones.
    """
    def __init__(self):
        super().__init__()
        self.expand = True
        self.padding = 20
        
        # Componentes del encabezado
        self.title = ft.Text("Modpack Overrides", size=28, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE)
        self.subtitle = ft.Text(
            "Gestiona y visualiza los archivos marcados con 'preserve = true' en la configuración de Packwiz.",
            color=ft.Colors.WHITE54,
            size=14
        )
        
        self.refresh_btn = ft.ElevatedButton(
            "Recargar Datos",
            icon=ft.Icons.REFRESH,
            on_click=self.load_data,
            style=ft.ButtonStyle(
                shape=ft.RoundedRectangleBorder(radius=8),
                padding=ft.Padding(left=20, top=15, right=20, bottom=15)
            )
        )
        
        # Tabla de datos
        self.data_table = ft.DataTable(
            expand=True,
            columns=[
                ft.DataColumn(ft.Text("Estado")),
                ft.DataColumn(ft.Text("Archivo")),
                ft.DataColumn(ft.Text("Ruta Relativa")),
                ft.DataColumn(ft.Text("Acciones")),
            ],
            rows=[]
        )
        
        # Estructura del Layout
        border_style = ft.Border(
            top=ft.BorderSide(1, "#30363D"), 
            right=ft.BorderSide(1, "#30363D"), 
            bottom=ft.BorderSide(1, "#30363D"), 
            left=ft.BorderSide(1, "#30363D")
        )

        self.content = ft.Column(
            expand=True,
            controls=[
                ft.Row(
                    [
                        ft.Column([self.title, self.subtitle], expand=True),
                        self.refresh_btn
                    ], 
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER
                ),
                ft.Divider(height=30, color="#30363D"),
                ft.Container(
                    expand=True,
                    border=border_style,
                    border_radius=12,
                    padding=0,
                    clip_behavior=ft.ClipBehavior.HARD_EDGE,
                    content=ft.ListView(
                        expand=True,
                        controls=[self.data_table]
                    )
                )
            ]
        )
        
    def did_mount(self):
        self.load_data(None)
        
    def load_data(self, e):
        """Obtiene la lista de overrides desde core.packwiz_parser y repuebla la tabla."""
        overrides = get_overrides()
        self.data_table.rows.clear()
        
        if not overrides:
            self.data_table.rows.append(
                ft.DataRow(
                    cells=[
                        ft.DataCell(ft.Icon(ft.Icons.INFO, color=ft.Colors.BLUE)),
                        ft.DataCell(ft.Text("No se encontraron overrides.")),
                        ft.DataCell(ft.Text("-")),
                        ft.DataCell(ft.Text("-")),
                    ]
                )
            )
        else:
            for item in overrides:
                is_preserved = item.get("preserve", False)
                filename = item.get("filename", "Desconocido")
                filepath = item.get("path", "Ruta desconocida")
                
                # Lógica visual para identificar el estado 'preserve'
                status_icon = ft.Icon(
                    icon=ft.Icons.LOCK if is_preserved else ft.Icons.LOCK_OPEN,
                    color=ft.Colors.GREEN_500 if is_preserved else ft.Colors.GREY_400,
                    tooltip="Preservado (No se sobrescribe)" if is_preserved else "No Preservado (Se sobrescribe)"
                )
                
                # Botones de acción interactivos
                actions_row = ft.Row(
                    spacing=5,
                    controls=[
                        ft.IconButton(
                            icon=ft.Icons.EDIT_DOCUMENT,
                            icon_color=ft.Colors.BLUE_400,
                            tooltip="Editar configuración del archivo",
                            on_click=lambda e, f=item: self.handle_edit(f)
                        ),
                        ft.IconButton(
                            icon=ft.Icons.DELETE_OUTLINE,
                            icon_color=ft.Colors.RED_400,
                            tooltip="Remover override",
                            on_click=lambda e, f=item: self.handle_delete(f)
                        )
                    ]
                )
                
                # Fila de datos
                row = ft.DataRow(
                    cells=[
                        ft.DataCell(status_icon),
                        ft.DataCell(ft.Text(filename, weight=ft.FontWeight.W_500)),
                        ft.DataCell(ft.Text(filepath, color=ft.Colors.WHITE54)),
                        ft.DataCell(actions_row),
                    ]
                )
                self.data_table.rows.append(row)
        
        self.update()
            
    def handle_edit(self, item):
        print(f"Editar override: {item}")
        
    def handle_delete(self, item):
        print(f"Eliminar override: {item}")
