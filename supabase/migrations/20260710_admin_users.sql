-- Habilitar pgcrypto si no está habilitado
create extension if not exists pgcrypto;

-- Función para obtener la lista de usuarios con email
create or replace function public.get_admin_users()
returns table (
  id uuid,
  nombre text,
  email text,
  created_at timestamptz
) as $$
begin
  return query
  select 
    p.id,
    p.nombre,
    u.email,
    p.created_at
  from public.profiles p
  join auth.users u on p.id = u.id
  order by p.created_at desc;
end;
$$ language plpgsql security definer;

-- Función para crear un usuario (con su profile correspondiente)
create or replace function public.admin_create_user(
  user_email text,
  user_password text,
  user_nombre text
) returns uuid as $$
declare
  new_user_id uuid;
begin
  new_user_id := gen_random_uuid();
  
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000',
    new_user_id,
    'authenticated',
    'authenticated',
    user_email,
    crypt(user_password, gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object('nombre', user_nombre),
    now(),
    now()
  );
  
  -- El trigger on_auth_user_created se encargará de crear el registro en public.profiles automáticamente.
  -- Por si acaso no existiera o fallara el trigger, podemos verificar si se insertó y si no, insertarlo:
  if not exists (select 1 from public.profiles where id = new_user_id) then
    insert into public.profiles (id, nombre, created_at, updated_at)
    values (new_user_id, user_nombre, now(), now());
  end if;

  return new_user_id;
end;
$$ language plpgsql security definer;

-- Función para actualizar un usuario
create or replace function public.admin_update_user(
  user_id uuid,
  new_email text,
  new_password text,
  new_nombre text
) returns void as $$
begin
  -- Actualizar auth.users
  update auth.users
  set email = coalesce(new_email, email),
      encrypted_password = case 
        when new_password is not null and new_password <> '' then crypt(new_password, gen_salt('bf'))
        else encrypted_password
      end,
      raw_user_meta_data = raw_user_meta_data || jsonb_build_object('nombre', coalesce(new_nombre, raw_user_meta_data->>'nombre')),
      updated_at = now()
  where id = user_id;

  -- Actualizar public.profiles
  update public.profiles
  set nombre = coalesce(new_nombre, nombre),
      updated_at = now()
  where id = user_id;
end;
$$ language plpgsql security definer;

-- Función para eliminar un usuario
create or replace function public.admin_delete_user(
  user_id uuid
) returns void as $$
begin
  delete from auth.users where id = user_id;
end;
$$ language plpgsql security definer;
