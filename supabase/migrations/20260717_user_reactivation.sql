-- 1. Función para obtener un usuario eliminado por email
CREATE OR REPLACE FUNCTION public.get_deleted_user_by_email(email_to_check text)
RETURNS TABLE (
  id uuid,
  nombre text,
  email text,
  deleted_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.nombre,
    u.email::text,
    p.deleted_at
  FROM public.profiles p
  JOIN auth.users u ON p.id = u.id
  WHERE LOWER(u.email) = LOWER(email_to_check) AND p.deleted_at IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Función para reactivar un usuario (profile y auth.users)
CREATE OR REPLACE FUNCTION public.admin_reactivate_user(
  user_id uuid,
  new_password text,
  new_nombre text
) RETURNS void AS $$
BEGIN
  -- Reactivar en public.profiles
  UPDATE public.profiles
  SET deleted_at = NULL,
      nombre = COALESCE(new_nombre, nombre),
      updated_at = NOW()
  WHERE id = user_id;

  -- Actualizar contraseña y nombre en auth.users si se proporcionan
  UPDATE auth.users
  SET encrypted_password = CASE 
        WHEN new_password IS NOT NULL AND new_password <> '' THEN crypt(new_password, gen_salt('bf'))
        ELSE encrypted_password
      END,
      raw_user_meta_data = raw_user_meta_data || jsonb_build_object('nombre', COALESCE(new_nombre, raw_user_meta_data->>'nombre')),
      updated_at = NOW()
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
