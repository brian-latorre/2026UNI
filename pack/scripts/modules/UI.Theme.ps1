<#
    UI.Theme.ps1
    ═══════════════════════════════════════════════════════════════
    Paleta de colores y constantes visuales del Configurador 2026UNI.
    
    Se consume en GUI-Configurador.ps1 al construir el XAML.
    La paleta mantiene coherencia visual con el logo "2026 UNI"
    del modpack (blanco/rojo sobre negro).
    
    Cambiar un color aquí lo cambia en toda la GUI — no hay
    colores hardcodeados en el XAML (los estilos referencian
    estas variables vía ResourceDictionary o se inyectan al
    generar el string XAML).
    ═══════════════════════════════════════════════════════════════
#>

$Theme = @{
    # ── Fondos ──────────────────────────────────────────────────
    Background         = "#0B0B0B"     # Fondo principal de la ventana
    BackgroundSecondary = "#111111"    # Fondo de secciones internas (Expander)
    
    # ── Texto ───────────────────────────────────────────────────
    Foreground         = "#FFFFFF"     # Texto principal (títulos, labels)
    ForegroundMuted    = "#CCCCCC"     # Texto secundario (subtítulos, hints)
    TextMuted          = "#888888"     # Texto terciario (labels de sección)
    
    # ── Botones ─────────────────────────────────────────────────
    Accent             = "#BF1515"     # Rojo carmesí — botones de acción principal
    AccentHover        = "#D42020"     # Hover del rojo (ligeramente más claro)
    ButtonSecondary    = "#222222"     # Botones secundarios (Lite, Aplicar RAM)
    ButtonAdvanced     = "#1A1A1A"     # Botones dentro del Expander avanzado
    ButtonAdvancedText = "#AAAAAA"     # Texto de botones avanzados
    
    # ── Controles ───────────────────────────────────────────────
    SliderTrack        = "#333333"     # Track del slider de RAM
    SliderThumb        = "#BF1515"     # Thumb del slider (mismo rojo carmesí)
    CheckboxAccent     = "#BF1515"     # Color del check en ChkZGC
    Separator          = "#333333"     # Líneas divisorias
    
    # ── Ventana ─────────────────────────────────────────────────
    WindowWidth        = 420
    WindowHeight       = 580
}
