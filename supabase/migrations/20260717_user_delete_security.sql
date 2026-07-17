-- Actualizar la función para prevenir que un usuario se elimine a sí mismo
CREATE OR REPLACE FUNCTION public.admin_delete_user(user_id uuid) RETURNS void AS $$
BEGIN
  -- Prevenir que el usuario se elimine a sí mismo
  IF auth.uid() = user_id THEN
    RAISE EXCEPTION 'No puedes eliminar tu propio usuario administrador.';
  END IF;

  DELETE FROM auth.users WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
