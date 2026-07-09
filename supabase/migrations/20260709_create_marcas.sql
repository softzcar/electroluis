-- 1. Crear la tabla de marcas
CREATE TABLE IF NOT EXISTS marcas (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre text UNIQUE NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Habilitar RLS en marcas
ALTER TABLE marcas ENABLE ROW LEVEL SECURITY;

-- 3. Crear política de RLS para marcas
CREATE POLICY "Allow authenticated read/write on marcas" ON marcas
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- 4. Trigger automático set_updated_at para marcas
CREATE TRIGGER set_updated_at BEFORE UPDATE ON marcas
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 5. Insertar marcas existentes de la tabla equipos a la tabla marcas
INSERT INTO marcas (nombre)
SELECT DISTINCT TRIM(marca)
FROM equipos
WHERE marca IS NOT NULL AND TRIM(marca) <> ''
ON CONFLICT (nombre) DO NOTHING;

-- 6. Agregar la columna id_marca a la tabla de equipos
ALTER TABLE equipos ADD COLUMN IF NOT EXISTS id_marca bigint REFERENCES marcas(id);

-- 7. Asociar las marcas existentes de equipos a la tabla marcas por nombre
UPDATE equipos e
SET id_marca = m.id
FROM marcas m
WHERE TRIM(e.marca) = m.nombre;

-- 8. Hacer que id_marca sea NOT NULL
ALTER TABLE equipos ALTER COLUMN id_marca SET NOT NULL;

-- 9. Eliminar la columna de texto vieja marca
ALTER TABLE equipos DROP COLUMN IF EXISTS marca CASCADE;
