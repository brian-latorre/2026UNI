# Traducción al Español - 2026UNI Modpack

Este paquete de recursos contiene las traducciones corregidas y auditadas para el modpack 2026UNI.

## Progreso General

| Mod | Estado | Notas |
| :--- | :--- | :--- |
| **Cobblemon** | [Auditado] | Corregidos los caracteres corruptos () causados por mala codificación ANSI. |
| **Relics** | [Auditado] | Revisión completa de codificación UTF-8. |
| **Xaero's Better PVP** | [Corregido] | Puntos cardinales N, S, E, O. Traducción de llaves faltantes de en_us.json. |
| **Xaero's Minimap** | [Corregido] | Puntos cardinales N, S, E, O. Integración de +500 llaves faltantes (ej. Día). |
| **Xaero's World Map** | [Corregido] | Puntos cardinales N, S, E, O. Traducción de llaves faltantes (ej. Selección de mapa). |
| **JEI** | [Restaurado] | Textos originales restaurados directamente del archivo .jar. |
| **AppleSkin** | [Restaurado] | Textos originales restaurados directamente del archivo .jar. |
| **Waystones** | [Restaurado] | Textos originales restaurados directamente del archivo .jar. |
| **Clumps** | [Restaurado] | Textos originales restaurados directamente del archivo .jar. |
| **Comforts** | [Restaurado] | Textos originales restaurados directamente del archivo .jar. |

## Reporte de Incidentes (Traducciones Incompletas y Textos en Inglés)

**Problema:** Durante la revisión anterior, algunas traducciones (como Xaero's World Map y el minimapa) volvieron a estar en inglés (ej. "Day 2", o falta de "Selección de mapa") o tenían textos incompletos y corrupciones en la codificación.
**Causa raíz:** 
1. **Codificación:** Al procesar los archivos de idioma, un script de PowerShell leyó los archivos UTF-8 utilizando la codificación ANSI por defecto del sistema, lo que generó un problema de "doble codificación UTF-8" corrompiendo vocales acentuadas.
2. **Archivos Nativos Incompletos:** Muchos mods (especialmente la familia Xaero) no incluyen todas sus llaves de traducción en el archivo `es_es.json` de fábrica (por ejemplo, Xaero's Minimap omite más de 500 llaves que sólo existen en `en_us.json`). Al extraer los archivos originales de los mods para reiniciar el proceso, se borraron las correcciones manuales previas, exponiendo las traducciones nativas incompletas.

**Solución aplicada:**
- **Extracción limpia:** Se volvieron a extraer todos los archivos `es_es.json` originales desde los archivos `.jar` usando un script de Python 100% seguro con codificación UTF-8 (evitando PowerShell).
- **Fusión de llaves (Merge):** Se creó un script que compara `en_us.json` con `es_es.json`. Cualquier llave existente en inglés que faltara en español se inyectó en el archivo `es_es.json` para forzar su carga y se tradujeron las cadenas críticas de la interfaz de usuario (como "Día", "Selección de mapa", "Alternar dimensión", etc.).
- **Limpieza de Caracteres Unicode:** Se ejecutó un proceso de saneamiento automatizado para reemplazar el carácter de corrupción `` por sus respectivas vocales acentuadas en el archivo principal de Cobblemon.

## Glosario y Convenciones
- **Puntos Cardinales (Minimapas):** Se mantienen las iniciales universales (N, S, E, O) de forma estricta.
- **Términos Base:** Se respeta el vocabulario estándar de Minecraft Vanilla (ej. Mesa de trabajo, Pico).
- **Formatos:** Se conservan estrictamente los códigos de color (§) y variables (%s, %d).
