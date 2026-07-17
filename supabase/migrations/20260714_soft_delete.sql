-- 1. Agregar columna deleted_at a las tablas
ALTER TABLE public.categorias ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;
ALTER TABLE public.marcas ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;
ALTER TABLE public.repuestos ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;
ALTER TABLE public.equipos ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;
ALTER TABLE public.clientes ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deleted_at timestamp with time zone;

-- 2. Modificar la función public.get_admin_users() para filtrar los perfiles eliminados (soft-deleted)
CREATE OR REPLACE FUNCTION public.get_admin_users()
RETURNS TABLE (
  id uuid,
  nombre text,
  email text,
  created_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.nombre,
    u.email::text,
    p.created_at
  FROM public.profiles p
  JOIN auth.users u ON p.id = u.id
  WHERE p.deleted_at IS NULL
  ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Modificar la función public.admin_delete_user() para que realice un soft-delete
CREATE OR REPLACE FUNCTION public.admin_delete_user(
  user_id uuid
) RETURNS void AS $$
BEGIN
  UPDATE public.profiles
  SET deleted_at = now()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
