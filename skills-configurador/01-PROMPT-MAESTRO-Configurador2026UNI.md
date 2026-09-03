# PROMPT MAESTRO — Configurador Gráfico 2026UNI

## Rol

Eres un ingeniero senior de PowerShell/WPF construyendo el "Configurador 2026UNI": una GUI complementaria de escritorio para un ecosistema de Minecraft Forge 1.20.1 (~300 mods) distribuido con Packwiz. Trabaja fase por fase, en el orden dado. No avances a la siguiente fase sin haber cerrado el "contrato" (nombres de controles/funciones) que la fase actual debe entregar.

---

## PASO 0 — Input obligatorio (rellenar antes de ejecutar)

El botón `ChkZGC` y la nueva función de RAM escriben sobre el archivo de argumentos JVM de la instancia en PineconeMC. Sin ver su formato real, cualquier regex que se escriba es una suposición.

```
<<RELLENAR: ARCHIVO DE ARGUMENTOS JVM>>
Ruta relativa del archivo: ___________________________
Contenido actual completo:
___________________________________________________
___________________________________________________
```

Si este bloque llega vacío, la IA debe detenerse en la Fase 3 y pedirlo explícitamente en vez de inventar una estructura.

---

## Contexto fijo del proyecto (no negociable)

- **Lenguaje:** PowerShell 7+ nativo.
- **GUI:** WPF (XAML) inyectado en PowerShell vía `[xml]$xaml = @"..."@`.
- **Prohibido:** Python, WinForms (`System.Windows.Forms`), cualquier compilado externo. El script corre 100% nativo en Windows 10/11, sin dependencias que el jugador tenga que instalar.
- **Lanzador:** `Configurador Grafico.bat` →
  `start /min powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0scripts\GUI-Configurador.ps1"`
- **Rutas:** siempre `$PSScriptRoot`, nunca rutas absolutas tipo `C:\Users\...`. El script es portable dentro del propio modpack.
- **Cliente Madre:** `C:\Users\brian\AppData\Roaming\.minecraft\2026UNI`
- **Cliente Lite:** `C:\Users\brian\AppData\Roaming\.minecraft\2026UNI_Lite`
- **Plantillas:** `$PSScriptRoot\..\presets_graficos\Normal\` y `\Lite\`, cada una con `embeddium-options.json` y `oculus.properties`.
- **Regla de mantenimiento único:** atajos de teclado y mods generales se editan SOLO desde el Cliente Madre. El Lite hereda ese core; solo difiere en gráficos.
- **Blacklist de Packwiz:** `embeddium-options.json` y `oculus.properties` nunca los sincroniza Packwiz — solo esta GUI los toca, copiando desde `presets_graficos/`.
- **Intocables siempre:** `xaero/` y `saves/`. Ninguna función de restauración puede tocarlos jamás, bajo ninguna circunstancia.

---

## Árbol de archivos objetivo

```
2026UNI-Configurador/
├── Configurador Grafico.bat
├── scripts/
│   ├── GUI-Configurador.ps1          # Entry point: carga XAML, conecta eventos, muestra ventana
│   ├── modules/
│   │   ├── UI.Theme.ps1              # Paleta de colores y estilos WPF reutilizables
│   │   ├── Perfil.Manager.ps1        # BtnNormal / BtnLite -> perfil.txt
│   │   ├── JVM.Manager.ps1           # ChkZGC + lógica de RAM (-Xmx/-Xms)
│   │   ├── Graficos.Restaurador.ps1  # BtnRestoreAll / BtnFixEmbeddium / BtnFixOculus / BtnFixOptions
│   │   └── Utils.Logging.ps1         # Try/Catch global, logging a archivo, backups .bak
│   └── assets/
│       └── icon.ico
├── presets_graficos/
│   ├── Normal/ (embeddium-options.json, oculus.properties)
│   └── Lite/   (embeddium-options.json, oculus.properties)
├── docs/
│   ├── README-tecnico.md
│   └── diagrama-flujo.md
└── logs/                              # se crea en tiempo de ejecución, no se versiona
```

---

## Contrato de controles XAML (nombres exactos — usar en toda fase)

| x:Name | Tipo | Acción que dispara |
|---|---|---|
| `BtnNormal` | Button | `Set-Perfil -Nombre "Normal"` |
| `BtnLite` | Button | `Set-Perfil -Nombre "Lite"` |
| `ChkZGC` | CheckBox | `Set-MotorGC -Motor ZGC` / `G1GC` |
| `SliderRAM` | Slider | Preview en vivo de GB seleccionados |
| `TxtRAMInfo` | TextBlock | Muestra "Recomendado: X GB · Y GB libres ahora" |
| `BtnAplicarRAM` | Button | `Set-RAM -GB $SliderRAM.Value` |
| `ExpanderAvanzado` | Expander | Contenedor colapsado para las 4 filas siguientes |
| `BtnRestoreAll` | Button | `Restore-TodosLosGraficos` |
| `BtnFixEmbeddium` | Button | `Restore-Embeddium` |
| `BtnFixOculus` | Button | `Restore-Oculus` |
| `BtnFixOptions` | Button | `Restore-OptionsTxt` (nunca toca `xaero/` ni `saves/`) |
| `BtnSalir` | Button | Cierra la ventana |

Si en la Fase 2 se agrega o renombra algún control, esa fase debe actualizar esta tabla explícitamente antes de pasar a la Fase 3 — es el contrato que evita que backend y UI queden desincronizados.

---

## FASES

### Fase 0 — Validación de entorno
*(Subagente sugerido: ninguno; hazlo en la conversación principal, es corto.)*

PowerShell 7 sobre Windows puede cargar WPF, pero requiere el **Windows Desktop Runtime** instalado (no basta el runtime normal de .NET). Esto falla en silencio si no se valida antes:

```powershell
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml -ErrorAction Stop
} catch {
    # OJO: MessageBox de WinForms está prohibido por restricción del proyecto.
    # Este error puntual, al ocurrir ANTES de que WPF esté disponible, solo puede
    # reportarse por log/consola, nunca por popup.
    "[$(Get-Date -Format o)] FATAL: falta Windows Desktop Runtime. Descargar de https://dotnet.microsoft.com/download/dotnet" |
        Out-File "$PSScriptRoot\..\logs\fatal.log" -Append
    exit 1
}
```

Entregable de esta fase: confirmación de que el entorno carga WPF correctamente, y el archivo `Utils.Logging.ps1` con esta validación y un wrapper genérico de logging.

---

### Fase 1 — Módulos y contratos de función
*(Subagente sugerido: ninguno — es planificación, no código de producción.)*

Define las firmas de función que cada módulo va a exponer (nombre, parámetros, qué devuelve), sin implementarlas todavía. Esto es lo que la Fase 3 va a implementar y lo que la Fase 4 va a validar. Ejemplo de nivel de detalle esperado:

```
Set-Perfil(-Nombre)          -> escribe perfil.txt, retorna $true/$false
Set-MotorGC(-Motor)          -> hace backup .bak, aplica regex, retorna $true/$false
Get-RAMRecomendada()         -> retorna PSCustomObject (TotalGB, FreeGB, Recomendado, Advertencia)
Set-RAM(-GB)                 -> hace backup .bak, escribe -Xmx/-Xms, retorna $true/$false
Restore-TodosLosGraficos()   -> copia Normal|Lite -> cliente activo
Restore-Embeddium() / Restore-Oculus() / Restore-OptionsTxt()
Write-Log(-Mensaje, -Nivel)  -> log a archivo con timestamp
Backup-Antes(-Ruta)          -> copia Ruta a Ruta.bak-{timestamp} antes de sobrescribir
```

---

### Fase 2 — XAML (interfaz)
*(Subagente sugerido: `xaml-ui-designer`)*

Construir el árbol XAML completo respetando:
- Ventana `420x580`, `StackPanel` con márgenes amplios.
- Paleta: fondo `#0B0B0B`, texto `#FFFFFF`/`#CCCCCC`, botones principales `#BF1515`, `Cursor="Hand"` en todo elemento clickeable.
- `Expander` colapsado por defecto conteniendo `BtnRestoreAll`, `BtnFixEmbeddium`, `BtnFixOculus`, `BtnFixOptions` (son las herramientas destructivas/avanzadas).
- Usar exactamente los `x:Name` de la tabla de contrato de arriba.
- Coherencia visual con la pantalla principal del modpack (logo "2026 UNI" en blanco/rojo sobre negro).

Salida esperada: `scripts/GUI-Configurador.ps1` con el bloque `$xaml`, y la tabla de contrato confirmada o actualizada.

---

### Fase 3 — Lógica de backend
*(Subagente sugerido: `powershell-logic-engineer`)*

Implementar cada módulo de la Fase 1, conectado a los controles de la Fase 2 vía `$window.FindName("...")` y `.Add_Click({...})`.

**Reglas duras para esta fase:**
1. Todo archivo que se va a sobrescribir (config JVM, `embeddium-options.json`, `oculus.properties`, `options.txt`) pasa primero por `Backup-Antes` (copia `.bak-{timestamp}`, sin sobrescribir backups previos).
2. `Test-Path` antes de leer o escribir cualquier archivo externo. Si no existe, log + aviso al usuario, nunca una excepción sin capturar.
3. El swap de `-XX:+UseG1GC` / `-XX:+UseZGC` se hace con `-replace` sobre el contenido leído del archivo (formato confirmado en el Paso 0), reescribiendo solo esa porción, preservando el resto de argumentos JVM intactos.
4. `Restore-OptionsTxt` jamás debe listar, leer, ni escribir dentro de `xaero/` o `saves/` — ni siquiera para "revisar que no estén".
5. Cada función retorna `$true`/`$false` (o lanza una excepción capturada por el wrapper de `Utils.Logging.ps1`), nunca falla en silencio.

**Lógica de RAM (función `Get-RAMRecomendada`):**

```powershell
function Get-RAMRecomendada {
    <#
        Recomienda un -Xmx en GB según la RAM física total del equipo,
        no solo la libre en este instante. Se calcula sobre el TOTAL con
        una reserva para SO + navegador + Discord, y después se cruza
        contra la RAM libre real para advertir si en este momento no
        hay margen (ej. el jugador tiene Chrome con 40 pestañas abierto).
    #>
    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem

    $totalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)  # FreePhysicalMemory viene en KB

    $reserva = switch ($totalGB) {
        { $_ -le 8 }  { 2.5; break }
        { $_ -le 16 } { 4;   break }
        { $_ -le 32 } { 6;   break }
        default       { 8 }
    }

    $recomendado = [math]::Floor($totalGB - $reserva)

    # Piso en 4GB: con ~300 mods, por debajo de eso el pack puede no llegar
    # ni a la pantalla de título (OutOfMemoryError en el arranque).
    # Techo en 10GB: en Forge 1.20.1 un heap más grande no acelera nada,
    # solo alarga las pausas del recolector de basura — y esto se nota
    # más todavía con ZGC, que tiene más overhead base que G1GC.
    $recomendado = [math]::Max(4, [math]::Min($recomendado, 10))

    [PSCustomObject]@{
        TotalGB     = $totalGB
        FreeGB      = $freeGB
        Recomendado = $recomendado
        Advertencia = ($freeGB -lt ($recomendado + 1))
    }
}
```

`Set-RAM -GB` debe: 1) hacer `Backup-Antes` del archivo de argumentos JVM, 2) reemplazar `-Xmx\d+[GgMm]` y `-Xms\d+[GgMm]` (o el patrón real confirmado en el Paso 0) por los nuevos valores, 3) usar `-Xms` igual a `-Xmx` o a la mitad, según lo que ya venga configurado — no inventar una convención nueva sin verificar el archivo real.

**Consideración sobre ZGC:** dado que ZGC tiene más overhead de memoria base que G1GC, si `ChkZGC` está activo y el usuario intenta aplicar una RAM por debajo de ~5-6GB, vale la pena mostrar una advertencia (no bloquear, solo avisar) en `TxtRAMInfo`.

---

### Fase 4 — Validación cruzada
*(Subagente sugerido: `qa-integration-validator`, agente de solo-lectura)*

Este subagente NO escribe código. Revisa y reporta:
1. Que cada `x:Name` referenciado en el backend exista literalmente en el XAML (y viceversa: ningún control huérfano sin handler, salvo los puramente decorativos).
2. Sintaxis de cada `.ps1` con el parser nativo, sin ejecutar el script:
   ```powershell
   $errors = $null
   [System.Management.Automation.Language.Parser]::ParseFile($ruta, [ref]$null, [ref]$errors) | Out-Null
   if ($errors) { $errors }
   ```
3. Que ninguna función toque `xaero/` o `saves/` (grep de esas dos cadenas en todo `scripts/`).
4. Que todo `Set-*` que sobrescribe un archivo llame a `Backup-Antes` antes.
5. Que todo acceso a archivo externo esté detrás de un `Test-Path`.

Entrega una lista PASS/FAIL. Los FAIL vuelven a la Fase 3 (mismo subagente `powershell-logic-engineer` o la conversación principal) para corregirse — este subagente no corrige, solo detecta.

---

### Fase 5 — Empaquetado
Confirmar que `Configurador Grafico.bat` lanza sin ventana de consola visible, que el ícono (`assets/icon.ico`) se aplica a la ventana WPF, y que un doble-click desde una copia recién descomprimida del modpack (rutas relativas puras, sin nada hardcodeado) funciona igual que desde la carpeta de desarrollo.

Agregar también:
- **Mutex de instancia única:** evitar que el jugador abra el configurador dos veces y ambas copias escriban sobre el mismo archivo a la vez.
- **Manejo de errores global:** todo el cuerpo de `GUI-Configurador.ps1` envuelto en `try/catch`; cualquier excepción no capturada debe loguearse en `logs/` y mostrar un `MessageBox` **de WPF** (`[System.Windows.MessageBox]`, no WinForms) con un mensaje entendible para el jugador — nunca dejar que la ventana se cierre sola sin explicación, porque corre oculta (`-WindowStyle Hidden`) y el jugador no va a ver nada en consola.

---

### Fase 6 — Documentación de estudio
*(Subagente sugerido: `technical-writer`)*

Generar `docs/README-tecnico.md` explicando, para que tú puedas estudiarlo y detectar errores por tu cuenta:
- Diagrama de flujo (Mermaid) de qué pasa desde que se hace doble-click en el `.bat` hasta que la ventana aparece.
- Por qué cada decisión técnica es como es (por qué `$PSScriptRoot`, por qué backups `.bak`, por qué el patrón de plantillas aísla esos dos archivos de Packwiz).
- Explicación función por función de cada módulo.
- Glosario mínimo de los conceptos usados (WPF/XAML, `Add-Type`, `Get-CimInstance`, el truco de `FreePhysicalMemory / 1MB` para convertir KB a GB, regex con `-replace`, el parser estático de PowerShell).

---

### Fase 7 — Checklist de aceptación (QA manual)

- [ ] Doble-click en `Configurador Grafico.bat` no muestra ninguna consola.
- [ ] Cambiar de perfil no borra ni toca `saves/` ni `xaero/`.
- [ ] Activar/desactivar `ChkZGC` deja el resto de argumentos JVM intactos (diff manual del archivo antes/después).
- [ ] `Get-RAMRecomendada` da un número sensato en una máquina de 8GB y en una de 32GB.
- [ ] Cada botón de restauración crea un `.bak` antes de sobrescribir.
- [ ] Forzar un error (ej. borrar temporalmente `presets_graficos/Normal/`) produce un log legible y un `MessageBox`, no un cierre silencioso.
- [ ] `docs/README-tecnico.md` te permite explicar en tus propias palabras qué hace cada botón, sin volver a leer el código.
