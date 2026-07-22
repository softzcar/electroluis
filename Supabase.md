# Supabase — electroluis

Proyecto: `electroluis` (ref: `wkqflxsqhmizekywchpu`, region: us-east-1)

Autenticación: **Supabase Auth** (no se maneja password manualmente). Cada usuario autenticado
obtiene automáticamente una fila en `profiles` vía trigger `on_auth_user_created`.

Convenciones aplicadas:
- Llaves primarias: `bigint generated always as identity` (excepto `profiles.id`, que es `uuid` y
  espeja `auth.users.id`).
- Todas las tablas tienen `created_at` / `updated_at` (con trigger automático `set_updated_at`).
- Nombres de columnas sin tildes.
- RLS habilitado en todas las tablas; política actual: cualquier usuario autenticado puede
  leer/escribir (herramienta interna de un solo taller). Ajustar si se necesitan roles distintos.

## Tablas

### profiles
Datos adicionales de usuario, ligados 1 a 1 con `auth.users`.

- `id` uuid PK → `auth.users.id` (on delete cascade)
- `nombre` text
- `created_at`, `updated_at`

### categorias
Catálogo de categorías de repuestos.

- `id` PK
- `nombre` text, unique, not null
- `created_at`, `updated_at`

### marcas
Catálogo de marcas de equipos.

- `id` PK
- `nombre` text, unique, not null
- `created_at`, `updated_at`

### repuestos

- `id` PK
- `nombre` text, not null
- `id_categoria` → `categorias.id`, not null
- `cantidad` integer, not null, default 0
- `ubicacion` text
- `codigo_barras` text, unique (nullable — no todos los repuestos tienen barcode aún)
- `created_at`, `updated_at`

### equipos
Un registro por aparato físico. Se reutiliza entre visitas (permite historial de reparación
por equipo vía `movimientos_equipos`).

- `id` PK
- `id_marca` → `marcas.id`, not null
- `modelo` text, not null
- `created_at`, `updated_at`

### clientes

- `id` PK
- `nombre` text, not null
- `telefono` text
- `rif` text
- `ubicacion_geografica` text
- `created_at`, `updated_at`

### movimientos
Registro de un servicio prestado (une cliente + usuario que atendió).

- `id` PK
- `id_cliente` → `clientes.id`, not null
- `id_user` → `profiles.id`, not null
- `descripcion` text
- `incluye_software` boolean, not null, default false
- `created_at`, `updated_at`

Nota: sin seguimiento de estado/fechas de reparación por ahora (decisión explícita, solo se
registra el servicio, no su ciclo de vida).

### movimientos_productos
Repuestos usados en un movimiento.

- `id` PK
- `id_movimiento` → `movimientos.id`, not null, on delete cascade
- `id_repuesto` → `repuestos.id`, not null
- `cantidad` integer, not null
- `created_at`, `updated_at`

### movimientos_equipos
Equipos atendidos en un movimiento.

- `id` PK
- `id_movimiento` → `movimientos.id`, not null, on delete cascade
- `id_equipo` → `equipos.id`, not null
- `nro_serie` text
- `created_at`, `updated_at`

### licencias
Catálogo de licencias de software.

- `id` PK
- `nombre` text, unique, not null
- `deleted_at` timestamp with time zone
- `created_at`, `updated_at`

### movimientos_licencias
Licencias instaladas en un movimiento.

- `id` PK
- `id_movimiento` → `movimientos.id`, not null, on delete cascade
- `id_licencia` → `licencias.id`, not null
- `key` text, not null
- `created_at`, `updated_at`

## Migraciones aplicadas

1. `create_profiles_and_auth_trigger`
2. `create_core_tables`
3. `enable_rls_policies`
4. `harden_functions` (search_path fijo + revoke execute en `handle_new_user`)
5. `add_codigo_barras_to_repuestos`
6. `update_equipos_serial`
7. `create_marcas`
8. `20260722_add_rif_to_clientes`
9. `20260722_add_software_and_licenses`
