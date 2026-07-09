-- 1. Eliminar la columna nro_serie y sus restricciones de la tabla de equipos
ALTER TABLE equipos DROP COLUMN IF EXISTS nro_serie CASCADE;

-- 2. Añadir la columna nro_serie a la tabla relacional movimientos_equipos
ALTER TABLE movimientos_equipos ADD COLUMN IF NOT EXISTS nro_serie TEXT;
