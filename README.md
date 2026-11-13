# Taller en Vivo 2.0

Sistema de producción de ventanas de uPVC: **Ventas** registra, sube la hoja de corte (PDF) y **Admin** la verifica. Después cada estación del **Taller** **recibe** el trabajo, lo **termina** y lo pasa a la siguiente. **Gerencia** sigue todo en el **dashboard ejecutivo**.

| Parte | Tecnología |
|---|---|
| Servidor y API REST | **FastAPI** (Python 3.14) + SQLAlchemy 2 |
| Base de datos | **MySQL 8.0** (InnoDB, utf8mb4) |
| Interfaz web | **Vue 3** + Chart.js + PDF.js (incluidos: funciona sin internet) |
| Tiempo real | WebSocket `/api/ws` |
| Seguridad | Claves cifradas con bcrypt, sesiones JWT, permisos revisados en el servidor, bloqueo por intentos fallidos y auditoría |

La versión anterior (prototipo que guardaba en el navegador) sigue en `taller-en-vivo/`, sin cambios.

## Estructura

```
taller/
├── backend/
│   ├── app/
│   │   ├── main.py          → servidor, cabeceras de seguridad, WebSocket, interfaz web
│   │   ├── config.py        → lee backend/.env
│   │   ├── models.py        → tablas de MySQL
│   │   ├── domain.py        → reglas: etapas, permisos, riesgo, comparación PDF ↔ ventas
│   │   ├── security.py      → bcrypt, JWT, permisos
│   │   ├── services.py      → listas automáticas, estados, textos
│   │   ├── seed.py          → datos base y de ejemplo
│   │   ├── cli.py           → instalación (configurar, iniciar-db, esquema…)
│   │   └── routers/         → auth, ventas, hojas, taller, admin, usuarios
│   ├── servidor.py          → arranca el servidor
│   ├── requirements.txt
│   ├── .env                 → claves (NO compartir)
│   └── privado/             → script SQL y credenciales iniciales (NO compartir)
├── frontend/                → interfaz Vue 3 (index.html, css, js/vistas/*)
├── database/schema.sql      → esquema MySQL de referencia
├── iniciar.bat              → abre el servidor y el navegador
├── Taller en Vivo.vbs       → lo mismo sin ventanas (para el acceso directo)
└── taller-en-vivo/          → versión anterior
```

## Instalación en esta PC

### 1. Encender MySQL 8 (como administrador)
En esta PC hay **3 servicios de MySQL** (`MySQL80`, `MySQL80_2` y `MySQL80_3`) que usan la **misma carpeta de datos** y chocan entre sí. Abre **PowerShell como administrador** y deja solo uno:

```powershell
Set-Service MySQL80_2 -StartupType Disabled
Set-Service MySQL80_3 -StartupType Disabled
Start-Service MySQL80
```

Si `MySQL80` no arranca, revisa el final del archivo `C:\ProgramData\MySQL\MySQL Server 8.0\Data\DESKTOP-G5HBVID.err`. El MySQL de XAMPP también usa el puerto 3306: no lo enciendas al mismo tiempo.

### 2. Crear la base de datos y su usuario
Abre **MySQL Workbench**, conéctate como `root` y ejecuta el script **`backend/privado/crear_usuario_mysql.sql`**. Crea la base `taller_en_vivo` y el usuario `taller_app`, con permisos **solo** sobre esa base y con la contraseña que ya está en `backend/.env`. La aplicación nunca usa `root`.

### 3. Crear las tablas y los datos iniciales
```bash
cd backend
.venv\Scripts\python.exe -m app.cli iniciar-db
```
Crea las tablas, los roles y un usuario **`admin`** con una contraseña temporal. Si `CARGAR_DEMO=true`, también carga datos de ejemplo inventados. Las credenciales quedan en `backend/privado/credenciales-iniciales.txt`: anótalas y **borra ese archivo**. El administrador debe cambiar la contraseña al entrar por primera vez.

> Para producción sin datos de ejemplo, pon `CARGAR_DEMO=false` en `.env` **antes** de este paso.

### 4. Abrir el programa
Doble clic en **`iniciar.bat`** (o en `Taller en Vivo.vbs`) y entra en **http://localhost:5517**.

Si algún día hace falta rehacer el entorno de Python:
```bash
cd backend
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
```

## Roles

| Rol | Qué hace |
|---|---|
| Operario | Recibe y termina el trabajo de **su estación** (se le puede fijar una) |
| Vendedor | Registra ventas, sube PDF, consulta pedidos |
| Jefe de ventas | Lo del vendedor + ventas urgentes |
| Supervisor de taller | Taller + tablero + resumen |
| Gerencia | Dashboard ejecutivo, tablero, resumen y consulta de ventas |
| Administrador | Todo, incluidas la auditoría y la administración de usuarios |

Los permisos de cada rol se cambian en **Usuarios y permisos** y valen de inmediato.

## Seguridad

- Las claves se guardan **cifradas con bcrypt**, nunca en texto. Operarios y ventas usan un **PIN de 4 a 8 números**; los roles de administración usan una **contraseña de 8 o más caracteres con letras y números**.
- Tras **5 intentos fallidos**, el usuario se bloquea 15 minutos. Un administrador puede desbloquearlo.
- Las sesiones usan **JWT** y duran 12 horas. Al cambiar la clave, desactivar al usuario o tocar "Salir", se cierran sus sesiones en todos los dispositivos.
- **Cada permiso se revisa en el servidor**, en cada llamada.
- La **auditoría** registra entradas, intentos fallidos con su IP, ventas, verificaciones, cambios de usuarios y cada acción del taller.
- Se revisa que los archivos sean de verdad PDF o imágenes (JPG, PNG o WEBP) y que no pasen el tamaño máximo. Se guardan fuera de la carpeta web y solo se entregan a usuarios con sesión.
- El servidor envía cabeceras de seguridad (CSP, `X-Frame-Options`, `nosniff`).
- Siempre queda al menos un administrador activo.

> **OneDrive:** esta carpeta se sincroniza con la nube, y con ella `backend/.env` y `backend/privado/`, que tienen claves. Para producción conviene instalar el servidor en una carpeta **fuera de OneDrive** (por ejemplo `C:\TallerEnVivo`) o excluir esas carpetas de la sincronización.

## Producción (red del taller y Android)

1. En `backend/.env` pon `HOST=0.0.0.0` para que tablets y celulares de la red local puedan entrar.
2. **Usa HTTPS.** Pon delante un *proxy* inverso (Caddy o Nginx) con certificado, o un túnel. Sin HTTPS, las claves viajan sin cifrar por la red.
3. Abre en el firewall de Windows solo el puerto del proxy.
4. Haz copias de seguridad diarias de MySQL (`mysqldump taller_en_vivo`) y de `backend/storage/`, donde están los PDF y las fotos.

## API para la app Android

La documentación interactiva está en **http://localhost:5517/api/docs**. Flujo de una estación:

```http
POST /api/auth/login                      {"usuario":"lherrera","clave":"1111"}  → {"token": "..."}
# En cada llamada:  Authorization: Bearer <token>
GET  /api/taller/filtros                  → listas semanales y colores con trabajo
GET  /api/taller/estaciones?lista=&color= → por recibir / en proceso / detenidas en cada estación
GET  /api/taller/estaciones/0/items       → hoja completa de cada ítem en Corte (vista=pend|hechos|todos)
POST /api/taller/items/{id}/acciones      {"accion":"recibir","estacion":0}
POST /api/taller/items/{id}/acciones      {"accion":"terminar","estacion":0}
POST /api/taller/items/{id}/acciones      {"accion":"detener","estacion":0,"nota":"Falta felpa"}
POST /api/taller/items/{id}/acciones      {"accion":"reanudar" | "deshacer","estacion":0}
POST /api/taller/items/{id}/foto?estacion=0   (multipart: archivo)
WS   /api/ws?token=<token>                → {"tipo":"cambio","que":["taller"]} cuando algo cambia
```

Reglas que el servidor hace cumplir:
- No se termina sin haber recibido antes.
- Un operario con estación fija solo marca la suya.
- Si dos personas tocan a la vez, la segunda recibe `409`.
- "Deshacer" solo funciona mientras la estación siguiente no haya recibido el trabajo.

En Android, guarda el token en `EncryptedSharedPreferences` y usa Retrofit/OkHttp con HTTPS.

## Comandos útiles

```bash
.venv\Scripts\python.exe -m app.cli esquema            # regenera database/schema.sql
.venv\Scripts\python.exe -m app.cli nuevo-admin jefe   # otro administrador con contraseña temporal
```

## Próximos pasos sugeridos
- La app Android de las estaciones, con la API de arriba.
- Migraciones con Alembic, cuando cambien las tablas en producción.
- Códigos QR por ítem, para que la estación lo abra escaneando.
- Proyectos grandes organizados en Proyecto → Lote (piso, bloque) → Ventana.
