-- 1. Agregar columna rif a la tabla clientes
ALTER TABLE public.clientes ADD COLUMN IF NOT EXISTS rif text;

-- 2. Actualizar la función public.get_client_by_phone_last_10 para que retorne el campo rif
DROP FUNCTION IF EXISTS public.get_client_by_phone_last_10(text);

CREATE OR REPLACE FUNCTION public.get_client_by_phone_last_10(phone_to_check text)
RETURNS TABLE (
  id bigint,
  nombre text,
  telefono text,
  ubicacion_geografica text,
  rif text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  deleted_at timestamp with time zone
) AS $$
DECLARE
  clean_phone text;
BEGIN
  -- Limpiar el número ingresado dejando solo dígitos y extrayendo los últimos 10
  clean_phone := RIGHT(REGEXP_REPLACE(phone_to_check, '\D', '', 'g'), 10);
  
  IF clean_phone IS NULL OR LENGTH(clean_phone) < 10 THEN
    RETURN QUERY
    SELECT c.id, c.nombre, c.telefono, c.ubicacion_geografica, c.rif, c.created_at, c.updated_at, c.deleted_at
    FROM public.clientes c
    WHERE c.telefono = phone_to_check;
  ELSE
    RETURN QUERY
    SELECT c.id, c.nombre, c.telefono, c.ubicacion_geografica, c.rif, c.created_at, c.updated_at, c.deleted_at
    FROM public.clientes c
    WHERE c.telefono IS NOT NULL 
      AND RIGHT(REGEXP_REPLACE(c.telefono, '\D', '', 'g'), 10) = clean_phone;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
