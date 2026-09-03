# Guía de uso — Configurador 2026UNI

## Qué hay en esta entrega

| Archivo | Para qué sirve |
|---|---|
| `01-PROMPT-MAESTRO-Configurador2026UNI.md` | El brief completo. Se lo pegas a Claude Code como primer mensaje dentro de la carpeta del proyecto. |
| `agents/xaml-ui-designer.md` | Subagente: solo interfaz (XAML). |
| `agents/powershell-logic-engineer.md` | Subagente: solo backend (PowerShell). |
| `agents/qa-integration-validator.md` | Subagente: solo revisión/validación, no escribe código. |
| `agents/technical-writer.md` | Subagente: solo documentación de estudio. |

## Antes de arrancar (obligatorio)

**No sé cuál es el formato real del archivo de argumentos JVM de la instancia en PineconeMC** (si es un `instance.cfg` estilo MultiMC/Prism con una línea `JvmArgs=...`, un `.json`, o algo propio tuyo). El botón `ChkZGC` y la nueva función de RAM dependen de ese archivo. Si dejo que la IA lo adivine, hay altas probabilidades de que el regex apunte al lugar equivocado.

Antes de correr el prompt maestro:
1. Abre esa instancia en PineconeMC y localiza el archivo con los argumentos JVM.
2. Copia su ruta relativa (respecto a la carpeta del cliente) y pega **el contenido actual completo** de ese archivo.
3. Pégalo en el bloque `<<RELLENAR: ARCHIVO DE ARGUMENTOS JVM>>` que está al inicio del prompt maestro, sección "Paso 0".

Todo lo demás del prompt ya está completo con lo que me diste.

## Cómo instalar los subagentes

1. En la raíz del repo del Configurador, crea la carpeta `.claude/agents/` si no existe.
2. Copia ahí los 4 archivos de la carpeta `agents/` de esta entrega, tal cual (no cambies el `name:` del frontmatter — el prompt maestro los referencia por ese nombre exacto).
3. Abre Claude Code en esa carpeta.

## Cómo correrlo

1. Pega el contenido de `01-PROMPT-MAESTRO-Configurador2026UNI.md` (ya con el Paso 0 relleno) como primer mensaje.
2. Claude Code debería delegar automáticamente a cada subagente según la fase (la `description` de cada uno está escrita para eso). Si en algún momento no delega solo, puedes forzarlo explícitamente: *"para esta fase, usa el subagente xaml-ui-designer"*.
3. Sigue las fases en orden — cada una depende del "contrato" (nombres de controles, nombres de funciones) que entrega la fase anterior. No saltes de Fase 2 a Fase 4 sin pasar por la 3.
4. Al final (Fase 7), pide explícitamente que se ejecute el checklist de QA antes de darlo por terminado.

## Nota sobre costo/tiempo

Cada subagente abre su propia ventana de contexto — no es gratis en tokens. Para un proyecto de este tamaño (un solo script GUI) vale la pena solo porque separa responsabilidades que de otra forma se pisan entre sí (UI vs lógica vs validación). Si en algún punto sientes que Claude Code está delegando de más para tareas triviales (un cambio de un color, un typo), dile que lo haga directo en la conversación principal — no todo necesita pasar por un subagente.
