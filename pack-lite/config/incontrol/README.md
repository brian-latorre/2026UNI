# 📘 Guía Maestra de InControl (Minecraft 1.20.1)

¡Hola! Esta es tu documentación personalizada y exclusiva para tu versión de juego (1.20.1). Muchos tutoriales en internet mencionan comandos o reglas antiguas (de la 1.12), pero aquí nos enfocaremos en **lo que realmente funciona en tu servidor hoy**.

InControl es una herramienta extremadamente poderosa, pero se divide en diferentes archivos según lo que quieras lograr.

---

## 📂 1. ¿Para qué sirve cada archivo?

InControl tiene varios archivos `.json`. Los tres más importantes para controlar la fauna y los monstruos son:

1. **`spawn.json` (El Interceptador):** Este archivo **escucha** cada vez que el juego (Vanilla) intenta generar un mob por su cuenta y te permite *interceptarlo*. Puedes usarlo para **cancelar** apariciones (`deny`), **permitirlas**, o alterar a los mobs justo cuando nacen (darles más vida, velocidad o daño).
2. **`spawner.json` (El Generador Forzado):** Es un motor independiente que añade InControl. Crea apariciones extra alrededor de los jugadores constantemente. Es el archivo que usamos para los monstruos. *Cuidado: si no le pones límites, puede llenar tu mundo de criaturas.*
3. **`potentialspawn.json` (El Editor de Biomas):** Se usa para decirle al juego: *'Quiero que este mob de este mod se agregue a la lista natural de este bioma'* (y darle un peso de aparición).

---

## ⚙️ 2. Entendiendo `spawner.json` (El Generador)

Este archivo crea reglas que el servidor lee cada segundo por cada jugador conectado. 

### Variables Principales:
* **`mob`**: Puede ser un solo mob (`"minecraft:zombie"`) o una lista entre corchetes `["mob1", "mob2"]`.
* **`persecond`**: **Probabilidad por segundo** de que la regla se ejecute. 
  * `1.0` = 100% de probabilidad cada segundo (¡Aparecerán a lo loco!).
  * `0.10` = 10% de probabilidad cada segundo (Un ritmo rápido pero controlable).
  * `0.02` = 2% de probabilidad (Encuentros raros).
* **`attempts`**: **Intentos de aparición**. Cuando la probabilidad (`persecond`) acierta, InControl intentará buscar un bloque válido para poner al mob. `1` significa que busca una vez, si el bloque no sirve, cancela. `5` significa que busca en 5 bloques distintos hasta encontrar espacio libre.
* **`amount`**: Diccionario con `"minimum"` y `"maximum"`. Indica **cuántos** mobs van a aparecer en un solo grupo de golpe. Ej: de 2 a 4 zombis juntos.

### El Bloque `"conditions"` (Condiciones):
Aquí es donde pones los límites. Si no los pones, el juego colapsa por sobrepoblación.
* **`mindist` y `maxdist`**: Distancia (en bloques) mínima y máxima desde el jugador. (Ej: `mindist: 24` evita que te aparezcan en la cara).
* **`minheight` y `maxheight`**: Altura mínima y máxima (Coordenada Y).
* **`maxlocal`**: **¡LÍMITE VITAL!** Cuenta cuántos mobs de esta regla hay a tu alrededor. Si el número actual es mayor a `maxlocal`, **aborta la aparición**. Evita que se llenen los campos.
* **`maxthis`**: Igual que el anterior, pero en vez de contar todos los de la regla, cuenta solo a esa especie específica.
* **`inwater`, `inair`, `inlava`**: Valores `true` o `false`. Determinan si el mob **debe** aparecer dentro de esos fluidos o aire.
* **`validspawn`**: **¡Regla de Oro en 1.18+!** Si lo pones en `true`, InControl verificará las reglas del juego nativo (Vanilla) para ese mob. Para los monstruos, significa que **solo aparecerán si hay oscuridad total (Nivel de luz 0)**, evitando que aparezcan de día en la superficie.
* **`biome`**: Lista de biomas donde puede suceder la regla. Acepta comodines como `"*jungle*"` (afecta a cualquier bioma que tenga jungla en el nombre).

---

## 🛡️ 3. Entendiendo `spawn.json` (El Interceptador)

A diferencia del anterior, aquí **no** usas `persecond` ni `attempts`, porque aquí no estás forzando apariciones, solo estás evaluando las que el juego ya iba a hacer por su cuenta.

### Variables Principales:
* **`mob` o `mod`**: Detecta a la criatura específica o a TODO el mod (Ej: `"mod": "tameablebeasts"`).
* **`result`**: Qué hacer con ese nacimiento.
  * `"deny"`: **Bloquea y elimina** la aparición. (Como lo usamos para extinguir a las bestias).
  * `"allow"`: Permite la aparición saltándose algunas restricciones.
  * `"default"`: Deja que el juego decida normalmente.

### Mejoras (Buffs) para hacer jefes o modos difíciles:
Si usas `"result": "default"`, puedes acompañarlo de estos parámetros (se aplican al nacer):
* **`healthmultiply`**: Multiplica la vida (Ej: `2.0` = doble de vida).
* **`damagemultiply`**: Multiplica el daño que hace el mob.
* **`speedmultiply`**: Multiplica la velocidad de movimiento.
*(Nota: Esto es ideal si quieres que todos los zombis que nazcan bajo la capa 0 (cuevas profundas) tengan el doble de vida y daño).*

---

## 🛠️ Consejos de tu Mentor
1. **El error de la luz antigua:** En versiones viejas (1.12), usábamos `minlight` y `maxlight` en `spawner.json`. En la 1.20.1 eso puede arrojar errores de sintaxis en `spawner.json`. La forma profesional y moderna de controlar la luz para monstruos es usar `"validspawn": true`.
2. **Cuidado con las comas (`,`)**: En formato JSON, el último elemento de una lista o bloque **nunca** debe llevar coma al final. Si pones una coma extra, InControl fallará al reiniciar y escupirá error en rojo.
3. **Recarga en vivo**: Siempre que edites los archivos, guarda el documento y escribe `/incontrol reload` en el chat de Minecraft. Revisa si sale un error en el chat; si no sale nada o dice "Rules reloaded", lo hiciste perfecto.
