-- 1. Agregar columna incluye_software a la tabla movimientos
ALTER TABLE public.movimientos ADD COLUMN IF NOT EXISTS incluye_software boolean NOT NULL DEFAULT false;

-- 2. Crear la tabla de licencias
CREATE TABLE IF NOT EXISTS public.licencias (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre text UNIQUE NOT NULL,
  deleted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Habilitar RLS en licencias
ALTER TABLE public.licencias ENABLE ROW LEVEL SECURITY;

-- 4. Crear política de RLS para licencias
CREATE POLICY "Allow authenticated read/write on licencias" ON public.licencias
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- 5. Trigger automático set_updated_at para licencias
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.licencias
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 6. Crear la tabla de movimientos_licencias
CREATE TABLE IF NOT EXISTS public.movimientos_licencias (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_movimiento bigint NOT NULL REFERENCES public.movimientos(id) ON DELETE CASCADE,
  id_licencia bigint NOT NULL REFERENCES public.licencias(id),
  key text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Habilitar RLS en movimientos_licencias
ALTER TABLE public.movimientos_licencias ENABLE ROW LEVEL SECURITY;

-- 8. Crear política de RLS para movimientos_licencias
CREATE POLICY "Allow authenticated read/write on movimientos_licencias" ON public.movimientos_licencias
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- 9. Trigger automático set_updated_at para movimientos_licencias
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.movimientos_licencias
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
