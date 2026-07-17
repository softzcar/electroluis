-- Función para buscar clientes por los últimos 10 dígitos del teléfono
CREATE OR REPLACE FUNCTION public.get_client_by_phone_last_10(phone_to_check text)
RETURNS TABLE (
  id bigint,
  nombre text,
  telefono text,
  ubicacion_geografica text,
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
    SELECT c.id, c.nombre, c.telefono, c.ubicacion_geografica, c.created_at, c.updated_at, c.deleted_at
    FROM public.clientes c
    WHERE c.telefono = phone_to_check;
  ELSE
    RETURN QUERY
    SELECT c.id, c.nombre, c.telefono, c.ubicacion_geografica, c.created_at, c.updated_at, c.deleted_at
    FROM public.clientes c
    WHERE c.telefono IS NOT NULL 
      AND RIGHT(REGEXP_REPLACE(c.telefono, '\D', '', 'g'), 10) = clean_phone;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
