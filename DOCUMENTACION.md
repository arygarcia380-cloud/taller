# Taller en Vivo — Qué es, cómo está hecho y su base de datos

> **Nota:** este documento describe la **versión anterior** (prototipo en `taller-en-vivo/`, datos en el navegador). La versión 2.0 con FastAPI, MySQL 8, Vue 3, seguridad y dashboard ejecutivo está explicada en [README.md](README.md).


## 1. ¿Qué hace la aplicación?

**Taller en Vivo** sirve para seguir la **producción de ventanas de uPVC**, desde la venta hasta que la ventana queda armada. Lo que un operario marca en su estación aparece en el tablero del supervisor.

Es **un solo programa con tres áreas**. Cada persona entra con su nombre y un **PIN de 4 números**, y solo ve lo que su rol le permite.

| Área | Quién la usa | Qué hace ahí |
|---|---|---|
| **Ventas** | Vendedor, Jefe de ventas | Registra ventas (de cliente o de proyecto), sube la hoja de corte en PDF de cada color y consulta cómo van los pedidos |
| **Taller** | Operarios | Ve las ventanas de su estación con la hoja de corte completa y marca su parte como "realizada" |
| **Admin** | Administrador, Supervisor | Tablero en vivo, verificación de los PDF, listas, pedidos, resumen de producción, usuarios y permisos |

### Flujo de trabajo

```
Ventas registra ──► Lista semanal abierta (7 días, separada por color)
                          │  se cierra sola al terminar la semana
                          ▼
Ventas sube el PDF "Cutting report" de cada color
                          ▼
Admin verifica: compara el PDF con las ventas (cliente + medida ±3 mm)
      ├─ Rechaza (con motivo) ──► vuelve a Ventas
      └─ Libera al taller
                          ▼
Taller: Corte → Enfelpado → Soldadura → Limpieza → Cerradura → Envidriado → Ensamblado
        (cada estación marca su parte con un botón; el ítem pasa a la siguiente)
                          ▼
Tablero y Resumen: estado en vivo, atrasos, detenciones, reporte para copiar
```

### Funciones principales
- **Listas automáticas:** las ventas entran solas a la lista abierta según su fecha. Al pasar el último día, la lista se cierra y se abre la siguiente.
- **Ventas urgentes:** se pueden meter directo en una lista que ya está en el taller (permiso `ventas.urgente`).
- **Tipos de venta:** *Cliente* (hasta 30 ventanas) o *Proyecto* (venta al por mayor, con empresa y obra).
- **Lector de PDF:** convierte el "Cutting report for quotation" en ítems con su despiece: perfiles, refuerzos, junquillos, empaques, vidrios, herrajes y elementos adicionales. Detecta el color por los códigos (ej. `TL80KH1.Negro`).
- **Verificación:** marca cada ítem como *Coincide*, *Faltan ventanas*, *Medida distinta*, *Sin venta registrada* o *Venta no está en el PDF*. Admin decide qué hacer con cada diferencia.
- **Taller:** muestra el checklist por estación, permite deshacer, reportar falta de material y subir una foto de evidencia.
- **Riesgo de entrega:** cada ventana aparece como Lista, Detenida, Atrasada, En riesgo, En proceso o En espera, según la fecha de entrega y las etapas que le faltan.
- **Resumen de producción:** por día, por rango de fechas, por pedido o por lista, con indicadores, tabla por etapa y un texto listo para pegar en WhatsApp o en un correo.
- **Funciona sin internet** y se instala como programa (PWA).

---

## 2. ¿Cómo está hecha?

Es un **prototipo solo de frontend**: no hay backend ni base de datos en un servidor. Está hecha con **HTML, CSS y JavaScript puro**, sin frameworks y sin `npm`.

| Pieza | Tecnología | Archivo |
|---|---|---|
| Interfaz | HTML5 (una sola página con secciones) | `index.html` |
| Estilos | CSS puro, modo claro/oscuro, diseño para celular | `css/styles.css` |
| Lógica | JavaScript (≈1300 líneas): datos, roles, permisos, pantallas y eventos | `js/app.js` |
| Lector de PDF | JavaScript + **PDF.js 3.11.174** (Mozilla), incluido en la carpeta para usarlo sin internet | `js/hoja-pdf.js`, `js/vendor/` |
| Modo sin internet | Service Worker (primero pide al servidor; si falla, usa la copia guardada) | `sw.js` |
| Instalable | Web App Manifest (nombre, ícono, colores) | `manifest.json`, `icons/` |
| Servidor local | **Python** (`http.server`), solo en `127.0.0.1:5517`, sin consola y uno a la vez | `servidor.py` |
| Lanzadores Windows | VBScript (abre el servidor oculto y una ventana de Edge `--app`) y un `.bat` | `Taller en Vivo.vbs`, `iniciar.bat` |

### Cómo está organizado el código (`app.js`)
1. **Configuración:** `STAGES` (las estaciones), `STAGE_HINT`, `COLORS`, `TIPOS`, `MAX_CLIENTE = 30` y `TODAY` (fecha fija de la demo: 5 nov 2026).
2. **Datos de ejemplo:** `listas`, `orders`, `events`, `hojas`, `roles` y `usuarios`.
3. **Permisos:** la función `puede("permiso")` se revisa en cada acción, no solo al dibujar los botones.
4. **Dibujo de pantallas:** `render()` vuelve a dibujar todo después de cada cambio (`renderStations`, `renderJobs`, `renderBoard`, etc.).
5. **Acciones:** un solo manejador de `click` lee el atributo `data-a` del botón (`start`, `finish`, `stop`, `resume`…).
6. **Guardado:** `save()` y `load()` (ver la sección 3).

### Cómo se ejecuta
```bash
python taller-en-vivo/servidor.py
```
Después se abre `http://localhost:5517/`. En esta PC ya están los accesos directos **Taller en Vivo** en el Escritorio y en el menú Inicio.

---

## 3. Base de datos (cómo se guarda hoy)

No hay base de datos en un servidor. Todo se guarda **dentro del navegador** de cada equipo, ligado a la dirección `http://localhost:5517`:

| Almacén | Nombre / clave | Qué guarda |
|---|---|---|
| `localStorage` | `taller-en-vivo-v4` | Un JSON con todo: `listas`, `orders`, `events`, `hojas`, `roles`, `usuarios`, la lista y el color elegidos, la fecha de la demo y la versión de los datos |
| `IndexedDB` | base `taller-en-vivo-pdf`, almacén `pdfs` | Los PDF originales que se suben |
| `sessionStorage` | `taller-en-vivo-sesion` | El id del usuario que entró |

- Si el `localStorage` se llena, se guarda otra vez **sin las fotos**.
- `load()` **migra datos viejos**. Por ejemplo, cuando "Preparación" pasó a ser "Cerradura" y se agregó "Envidriado", corrigió las etapas guardadas.
- **Restablecer datos de ejemplo** borra todo, incluidos los PDF.

### Estructuras de datos (las "tablas" actuales)

```js
// Lista semanal
listas  = { id:"L3", estado:"abierta"|"taller", desde:Date, hasta:Date }

// Orden = una ventana
orders  = { id:"P24", pedido:"PED-1040", venta:"cliente"|"proyecto", obra, fechaPedido:Date,
            lista:"L2", cliente:"Fam. Pérez", tipo:"Francesa", medida:"1.00 × 2.00 m",
            color:"Blanco", desde:Date, hasta:Date,          // rango de entrega
            stage:2,                                          // índice en STAGES; 7 = terminada
            status:"wait"|"run"|"stop"|"done", note, photo,
            checks:{ [etapa]: {quién, hora} }, item:{ hoja:"H6", n:3 } }

// Historial de actividad
events  = { ts:Date, id:"P24", a:"iniciar"|"terminar"|"detener"|"reanudar"|"foto"|"lista"|...,
            st:2, note, usuario }

// Hoja de corte (PDF) por lista y color
hojas   = { id:"H6", lista:"L2", color:"Negro", estado:"revision"|"rechazada"|"liberada",
            archivo:"NEGRO 5-17.pdf", cotizacion, entrega:Date, items:[...], decisiones:{...}, motivo }
item    = { n:3, pcs:2, ancho:1200, alto:1200, nota:"Cliente", tipo:"Corrediza",
            perfiles:[{grupo,code,name,size,aL,aR,pcs}], refuerzos, junquillos, empaques,
            vidrios, herrajes, adicionales }

// Seguridad
roles    = { id:"operario", nombre:"Operario", permisos:["taller.ver","taller.marcar"] }
usuarios = { id:"u1", nombre:"Luis Herrera", rol:"operario", pin:"1111",
             estacion:0, activo:true, pendiente? }
```

### Relaciones

```
listas 1 ──< orders >── 1 hojas (por lista + color)
orders 1 ──< events >── 1 usuarios >── 1 roles
hojas  1 ──< items  ──1 orders.item
```

### Roles y permisos de fábrica

| Rol | Permisos |
|---|---|
| Operario | `taller.ver`, `taller.marcar` (se le puede fijar una estación) |
| Vendedor | `ventas.ver`, `ventas.registrar`, `ventas.estado`, `ventas.pdf` |
| Jefe de ventas | Lo del vendedor + `ventas.urgente` |
| Supervisor de taller | Taller + `admin.tablero`, `admin.resumen` |
| Administrador | Todos (también `admin.verificar`, `admin.listas`, `admin.pedidos`, `admin.usuarios`) |

---

## 4. Limitaciones actuales

- **Los datos no se comparten entre equipos:** cada PC o celular tiene los suyos. El "tiempo real" solo funciona en la misma computadora.
- **No es seguridad real:** los PIN se guardan sin cifrar en el navegador.
- La fecha "de hoy" está fija para la demo. El botón *Avanzar un día* sirve para probar el cierre automático de las listas.
- Si cambia el puerto (5517), el programa empieza vacío.

## 5. Base de datos propuesta (siguiente paso)

Para que Ventas, Taller y Admin vean lo mismo desde distintos dispositivos:

- **Servidor:** Node.js + Express
- **Base de datos:** PostgreSQL (o SQLite para empezar)
- **Tiempo real:** WebSockets (Socket.IO)

```sql
CREATE TABLE roles        (id TEXT PRIMARY KEY, nombre TEXT NOT NULL);
CREATE TABLE rol_permisos (rol_id TEXT REFERENCES roles(id), permiso TEXT, PRIMARY KEY (rol_id, permiso));
CREATE TABLE usuarios     (id SERIAL PRIMARY KEY, nombre TEXT NOT NULL, rol_id TEXT REFERENCES roles(id),
                           pin_hash TEXT NOT NULL, estacion INT, activo BOOLEAN DEFAULT true,
                           pendiente BOOLEAN DEFAULT false);

CREATE TABLE etapas       (id SERIAL PRIMARY KEY, nombre TEXT NOT NULL, orden INT NOT NULL);
CREATE TABLE listas       (id SERIAL PRIMARY KEY, estado TEXT CHECK (estado IN ('abierta','taller')),
                           desde DATE, hasta DATE);
CREATE TABLE hojas        (id SERIAL PRIMARY KEY, lista_id INT REFERENCES listas(id), color TEXT,
                           estado TEXT CHECK (estado IN ('revision','rechazada','liberada')),
                           archivo_url TEXT, cotizacion TEXT, entrega DATE, motivo TEXT);
CREATE TABLE hoja_items   (id SERIAL PRIMARY KEY, hoja_id INT REFERENCES hojas(id), n INT, pcs INT,
                           ancho_mm INT, alto_mm INT, nota TEXT, tipo TEXT, despiece JSONB);

CREATE TABLE pedidos      (id SERIAL PRIMARY KEY, codigo TEXT UNIQUE, venta TEXT CHECK (venta IN ('cliente','proyecto')),
                           cliente TEXT, obra TEXT, fecha_pedido DATE, lista_id INT REFERENCES listas(id));
CREATE TABLE ventanas     (id SERIAL PRIMARY KEY, codigo TEXT UNIQUE, pedido_id INT REFERENCES pedidos(id),
                           hoja_item_id INT REFERENCES hoja_items(id), tipo TEXT, ancho_m NUMERIC, alto_m NUMERIC,
                           color TEXT, entrega_desde DATE, entrega_hasta DATE, etapa_id INT REFERENCES etapas(id),
                           estado TEXT CHECK (estado IN ('espera','proceso','detenida','lista')), nota TEXT);

-- Historial: cada vez que alguien marca algo (también sirve para medir tiempos y encontrar cuellos de botella)
CREATE TABLE eventos      (id SERIAL PRIMARY KEY, ventana_id INT REFERENCES ventanas(id),
                           etapa_id INT REFERENCES etapas(id), usuario_id INT REFERENCES usuarios(id),
                           accion TEXT, nota TEXT, foto_url TEXT, fecha TIMESTAMP DEFAULT now());
```

Otras mejoras pendientes: organizar los proyectos grandes en **Proyecto → Lote → Ventana**, poner **códigos QR** por ventana y guardar las fotos y los PDF en el servidor.
