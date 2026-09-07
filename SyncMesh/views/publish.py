import flet as ft
import asyncio

class PublishView(ft.Container):
    def __init__(self):
        super().__init__()
        self.expand = True
        self.padding = 20
        
        # UI Elements: Consola Virtual
        self.console_output = ft.ListView(
            expand=True,
            spacing=5,
            auto_scroll=True,
        )
        
        self.console_container = ft.Container(
            content=self.console_output,
            bgcolor=ft.Colors.BLACK87,
            border_radius=10,
            padding=15,
            expand=True,
            border=ft.Border(
                top=ft.BorderSide(1, ft.Colors.OUTLINE),
                bottom=ft.BorderSide(1, ft.Colors.OUTLINE),
                left=ft.BorderSide(1, ft.Colors.OUTLINE),
                right=ft.BorderSide(1, ft.Colors.OUTLINE)
            )
        )
        
        # UI Elements: Botones e Indicadores
        self.publish_btn = ft.ElevatedButton(
            "Publicar Modpack",
            icon=ft.Icons.ROCKET_LAUNCH,
            on_click=self.on_publish_click,
            style=ft.ButtonStyle(
                color=ft.Colors.WHITE,
                bgcolor=ft.Colors.BLUE_700,
            )
        )
        
        self.progress_ring = ft.ProgressRing(width=20, height=20, visible=False)
        
        self.content = ft.Column(
            controls=[
                ft.Row(
                    controls=[
                        ft.Text("Publicación de Modpack", size=24, weight=ft.FontWeight.BOLD),
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                ),
                ft.Text("Consola de Operaciones", size=16, weight=ft.FontWeight.W_500),
                self.console_container,
                ft.Row(
                    controls=[self.publish_btn, self.progress_ring],
                    alignment=ft.MainAxisAlignment.END
                )
            ]
        )

    def log_to_console(self, message: str, is_error: bool = False, is_success: bool = False, is_warning: bool = False):
        """Añade un mensaje a la consola virtual con formato de color dependiendo de su tipo."""
        color = ft.Colors.WHITE70
        if is_error:
            color = ft.Colors.RED_400
        elif is_success:
            color = ft.Colors.GREEN_400
        elif is_warning:
            color = ft.Colors.AMBER_400
            
        self.console_output.controls.append(
            ft.Text(f"> {message}", color=color, font_family="Consolas", size=13)
        )
        self.update() # Refresca el contenedor actual

    async def on_publish_click(self, e):
        """Simula la rutina de publicación asíncrona."""
        # Bloquear botón y mostrar spinner de carga
        self.publish_btn.disabled = True
        self.progress_ring.visible = True
        self.console_output.controls.clear()
        self.update()
        
        self.log_to_console("Iniciando pipeline de publicación de Modpack...", is_success=True)
        await asyncio.sleep(1)
        
        # --- Fase 1: Packwiz Refresh ---
        self.log_to_console("Ejecutando proceso: 'packwiz refresh'...")
        await asyncio.sleep(1)
        self.log_to_console("Sincronizando overrides y refrescando índices de mods...")
        await asyncio.sleep(1.5)
        # Aquí llamarías a tu función real, ej: await run_packwiz_refresh()
        self.log_to_console("✔ Archivo packwiz.json y metadatos actualizados correctamente.", is_success=True)
        
        await asyncio.sleep(1)
        
        # --- Fase 2: Inyección de Hashes ---
        self.log_to_console("Iniciando inyección de hashes vía core.packwiz_parser...")
        await asyncio.sleep(1)
        self.log_to_console("Analizando archivos .toml en entorno Cliente Madre...")
        await asyncio.sleep(1.5)
        
        # Aquí llamarías a la función real: await parse_and_inject_hashes()
        self.log_to_console("Generando y firmando hashes SHA-256 para módulos detectados...")
        await asyncio.sleep(2)
        
        # --- Finalización ---
        self.log_to_console("✔ Inyección completada exitosamente sin conflictos.", is_success=True)
        self.log_to_console("¡El Modpack ha sido publicado y está listo para ser obtenido por el Launcher!", is_success=True)
        
        # Restaurar estado UI
        self.publish_btn.disabled = False
        self.progress_ring.visible = False
        self.update()
