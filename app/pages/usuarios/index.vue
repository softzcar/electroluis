<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useSupabaseClient, useSupabaseUser } from '#imports'
import { UserCog, Trash2, Edit2, AlertCircle, CheckCircle, Mail, User, Lock, ShieldAlert, UserPlus, Info } from 'lucide-vue-next'

const supabase = useSupabaseClient()
const currentUser = useSupabaseUser()

const usuarios = ref<any[]>([])
const loading = ref(false)
const submitting = ref(false)
const errorMsg = ref('')
const successMsg = ref('')
const dbNotConfigured = ref(false)

const showDeleteConfirm = ref<string | null>(null) // Almacena el ID del usuario a eliminar

const form = reactive({
  id: null as string | null, // null = crear, uuid = editar
  nombre: '',
  email: '',
  password: ''
})

const errors = reactive({
  nombre: '',
  email: '',
  password: ''
})

const loadUsers = async () => {
  loading.value = true
  errorMsg.value = ''
  try {
    const { data, error } = await supabase.rpc('get_admin_users')
    if (error) {
      errorMsg.value = error.message
      if (error.message.includes('get_admin_users') || error.code === 'P0001') {
        dbNotConfigured.value = true
      }
    } else {
      usuarios.value = data ?? []
      dbNotConfigured.value = false
    }
  } catch (err: any) {
    errorMsg.value = err.message || 'Error cargando usuarios'
    dbNotConfigured.value = true
  } finally {
    loading.value = false
  }
}

onMounted(loadUsers)

const resetForm = () => {
  form.id = null
  form.nombre = ''
  form.email = ''
  form.password = ''
  
  errors.nombre = ''
  errors.email = ''
  errors.password = ''
}

const editUser = (user: any) => {
  resetForm()
  form.id = user.id
  form.nombre = user.nombre
  form.email = user.email
  // La contraseña queda vacía (solo se rellena si se desea cambiar)
}

const onSubmit = async () => {
  errors.nombre = ''
  errors.email = ''
  errors.password = ''
  
  let hasError = false
  
  if (!form.nombre.trim()) {
    errors.nombre = 'El nombre es obligatorio.'
    hasError = true
  }
  
  if (!form.email.trim()) {
    errors.email = 'El correo electrónico es obligatorio.'
    hasError = true
  } else if (!/\S+@\S+\.\S+/.test(form.email)) {
    errors.email = 'El formato del correo electrónico no es válido.'
    hasError = true
  }
  
  if (!form.id && !form.password) {
    errors.password = 'La contraseña es obligatoria para nuevos usuarios.'
    hasError = true
  } else if (form.password && form.password.length < 6) {
    errors.password = 'La contraseña debe tener al menos 6 caracteres.'
    hasError = true
  }
  
  if (hasError) return
  
  submitting.value = true
  errorMsg.value = ''
  successMsg.value = ''
  
  try {
    if (form.id) {
      // Editar usuario existente
      const { error: updateErr } = await supabase.rpc('admin_update_user', {
        user_id: form.id,
        new_email: form.email.trim(),
        new_password: form.password || null,
        new_nombre: form.nombre.trim()
      })
      if (updateErr) throw updateErr
      successMsg.value = 'Usuario actualizado correctamente.'
    } else {
      // Crear nuevo usuario
      const { error: createErr } = await supabase.rpc('admin_create_user', {
        user_email: form.email.trim(),
        user_password: form.password,
        user_nombre: form.nombre.trim()
      })
      if (createErr) throw createErr
      successMsg.value = 'Usuario creado correctamente.'
    }
    
    resetForm()
    await loadUsers()
    
    setTimeout(() => {
      successMsg.value = ''
    }, 4000)
    
  } catch (err: any) {
    errorMsg.value = err.message || 'Error en la operación de usuario.'
  } finally {
    submitting.value = false
  }
}

const deleteUser = async (userId: string) => {
  if (userId === currentUser.value?.id) {
    errorMsg.value = 'Acción bloqueada: No puedes eliminar tu propio usuario en uso.'
    return
  }
  
  loading.value = true
  errorMsg.value = ''
  
  try {
    const { error: deleteErr } = await supabase.rpc('admin_delete_user', {
      user_id: userId
    })
    if (deleteErr) throw deleteErr
    
    successMsg.value = 'Usuario eliminado de forma permanente.'
    showDeleteConfirm.value = null
    await loadUsers()
    
    setTimeout(() => {
      successMsg.value = ''
    }, 4000)
  } catch (err: any) {
    errorMsg.value = err.message || 'Error al eliminar el usuario.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="max-w-6xl mx-auto px-4 py-6 space-y-8 animate-fade-in">
    
    <!-- Encabezado -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-200 pb-5">
      <div>
        <h1 class="text-3xl font-extrabold text-slate-900 tracking-tight flex items-center gap-3">
          <span class="bg-gradient-to-r from-slate-900 to-slate-700 bg-clip-text text-transparent flex items-center gap-2">
            <UserCog class="h-8 w-8 text-slate-800" />
            Control de Usuarios
          </span>
        </h1>
        <p class="text-sm text-slate-500 mt-1">
          Crea nuevos operadores de Medic Play, gestiona sus credenciales de acceso o elimina sus cuentas.
        </p>
      </div>
      <div v-if="successMsg" class="flex items-center gap-2 bg-emerald-50 text-emerald-800 border border-emerald-200 px-4 py-2.5 rounded-xl text-sm shadow-sm">
        <CheckCircle class="h-4 w-4 text-emerald-600" />
        <span>{{ successMsg }}</span>
      </div>
    </div>

    <!-- Advertencia de Base de Datos no Configurada -->
    <div v-if="dbNotConfigured" class="bg-amber-50 border border-amber-200 rounded-3xl p-6 space-y-4">
      <div class="flex items-start gap-3">
        <ShieldAlert class="h-6 w-6 text-amber-600 shrink-0 mt-0.5" />
        <div>
          <h3 class="font-bold text-amber-900 text-base">Funciones de Administración Faltantes</h3>
          <p class="text-sm text-amber-800 mt-1">
            Para poder gestionar usuarios sin comprometer la seguridad o tu sesión activa, debes instalar las funciones SQL de administración en tu base de datos de Supabase.
          </p>
        </div>
      </div>
      <div class="bg-slate-900 text-slate-100 p-4 rounded-2xl text-xs font-mono overflow-x-auto max-h-60 space-y-1">
        <p class="text-slate-400">-- Copia y ejecuta este script en el editor SQL de tu Supabase Dashboard:</p>
        <pre>
-- 1. Habilitar extensión pgcrypto
create extension if not exists pgcrypto;

-- 2. Función para obtener usuarios con emails
create or replace function public.get_admin_users()
returns table (id uuid, nombre text, email text, created_at timestamptz) as $$
begin
  return query
  select p.id, p.nombre, u.email, p.created_at
  from public.profiles p
  join auth.users u on p.id = u.id
  order by p.created_at desc;
end;
$$ language plpgsql security definer;

-- 3. Función para crear usuarios
create or replace function public.admin_create_user(
  user_email text, user_password text, user_nombre text
) returns uuid as $$
declare new_user_id uuid;
begin
  new_user_id := gen_random_uuid();
  insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values (new_user_id, 'authenticated', 'authenticated', user_email, crypt(user_password, gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre', user_nombre), now(), now());
  
  if not exists (select 1 from public.profiles where id = new_user_id) then
    insert into public.profiles (id, nombre, created_at, updated_at) values (new_user_id, user_nombre, now(), now());
  end if;
  return new_user_id;
end;
$$ language plpgsql security definer;

-- 4. Función para actualizar usuarios
create or replace function public.admin_update_user(
  user_id uuid, new_email text, new_password text, new_nombre text
) returns void as $$
begin
  update auth.users
  set email = coalesce(new_email, email),
      encrypted_password = case when new_password is not null and new_password &lt;&gt; '' then crypt(new_password, gen_salt('bf')) else encrypted_password end,
      raw_user_meta_data = raw_user_meta_data || jsonb_build_object('nombre', coalesce(new_nombre, raw_user_meta_data->>'nombre')),
      updated_at = now()
  where id = user_id;
  update public.profiles set nombre = coalesce(new_nombre, nombre), updated_at = now() where id = user_id;
end;
$$ language plpgsql security definer;

-- 5. Función para eliminar usuarios
create or replace function public.admin_delete_user(user_id uuid) returns void as $$
begin
  delete from auth.users where id = user_id;
end;
$$ language plpgsql security definer;
        </pre>
      </div>
      <button 
        @click="loadUsers"
        class="bg-amber-600 hover:bg-amber-700 text-white font-semibold text-sm px-4 py-2 rounded-xl transition-colors"
      >
        Reintentar conexión
      </button>
    </div>

    <!-- Contenido Principal -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-12 gap-8">
      
      <!-- COLUMNA IZQUIERDA: Formulario de Registro / Modificación -->
      <div class="lg:col-span-5 space-y-6">
        <div class="bg-white rounded-3xl p-6 shadow-sm border border-slate-100 space-y-6">
          <h2 class="text-lg font-bold text-slate-800 flex items-center gap-2">
            <UserPlus class="h-5 w-5 text-slate-600" />
            {{ form.id ? 'Editar Credenciales' : 'Registrar Nuevo Operador' }}
          </h2>
          
          <form @submit.prevent="onSubmit" novalidate class="space-y-4">
            <!-- Campo Nombre -->
            <div>
              <label class="block text-sm font-semibold text-slate-700 mb-1">Nombre Completo</label>
              <div class="relative">
                <input 
                  v-model="form.nombre" 
                  placeholder="Ej. Carlos Mendoza"
                  :class="[
                    'w-full pl-3.5 pr-4 py-2 border rounded-xl focus:outline-none transition-all text-sm',
                    errors.nombre ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-950'
                  ]"
                  @input="errors.nombre = ''"
                >
              </div>
              <Transition name="fade">
                <span v-if="errors.nombre" class="text-xs text-red-600 mt-1.5 font-medium flex items-center gap-1">
                  <AlertCircle :size="14" class="shrink-0" /> {{ errors.nombre }}
                </span>
              </Transition>
            </div>

            <!-- Campo Correo -->
            <div>
              <label class="block text-sm font-semibold text-slate-700 mb-1">Correo Electrónico</label>
              <div class="relative">
                <input 
                  v-model="form.email" 
                  type="email"
                  placeholder="ejemplo@medicplay.com"
                  :class="[
                    'w-full pl-3.5 pr-4 py-2 border rounded-xl focus:outline-none transition-all text-sm',
                    errors.email ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-950'
                  ]"
                  @input="errors.email = ''"
                >
              </div>
              <Transition name="fade">
                <span v-if="errors.email" class="text-xs text-red-600 mt-1.5 font-medium flex items-center gap-1">
                  <AlertCircle :size="14" class="shrink-0" /> {{ errors.email }}
                </span>
              </Transition>
            </div>

            <!-- Campo Contraseña -->
            <div>
              <div class="flex justify-between items-center mb-1">
                <label class="block text-sm font-semibold text-slate-700">Contraseña</label>
                <span v-if="form.id" class="text-[11px] text-slate-400 font-semibold">Vacío para mantener actual</span>
              </div>
              <div class="relative">
                <input 
                  v-model="form.password" 
                  type="password"
                  placeholder="Mínimo 6 caracteres"
                  :class="[
                    'w-full pl-3.5 pr-4 py-2 border rounded-xl focus:outline-none transition-all text-sm',
                    errors.password ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-950'
                  ]"
                  @input="errors.password = ''"
                >
              </div>
              <Transition name="fade">
                <span v-if="errors.password" class="text-xs text-red-600 mt-1.5 font-medium flex items-center gap-1">
                  <AlertCircle :size="14" class="shrink-0" /> {{ errors.password }}
                </span>
              </Transition>
            </div>

            <!-- Alertas Generales de Error -->
            <div v-if="errorMsg" class="flex items-start gap-2.5 bg-rose-50 text-rose-800 border border-rose-100 px-4 py-3 rounded-2xl text-xs">
              <AlertCircle class="h-4.5 w-4.5 text-rose-600 shrink-0 mt-0.5" />
              <span>{{ errorMsg }}</span>
            </div>

            <!-- Botones de Acción -->
            <div class="flex gap-2 pt-2">
              <button 
                v-if="form.id"
                type="button"
                @click="resetForm"
                class="flex-1 px-4 py-2.5 border border-slate-200 rounded-xl text-sm font-semibold hover:bg-slate-50 text-slate-700 transition-colors"
              >
                Cancelar Edición
              </button>
              <button 
                type="submit" 
                :disabled="submitting"
                class="flex-1 bg-slate-950 hover:bg-slate-900 text-white font-bold py-2.5 px-4 rounded-xl transition-all shadow-md hover:shadow-lg disabled:opacity-50 text-sm"
              >
                {{ submitting ? 'Guardando...' : (form.id ? 'Actualizar Usuario' : 'Crear Usuario') }}
              </button>
            </div>
          </form>
        </div>
      </div>

      <!-- COLUMNA DERECHA: Lista de Operadores Registrados -->
      <div class="lg:col-span-7 space-y-6">
        <div class="bg-white rounded-3xl p-6 shadow-sm border border-slate-100 space-y-4">
          <h2 class="text-lg font-bold text-slate-800">Operadores Registrados</h2>
          
          <div class="overflow-x-auto border border-slate-100 rounded-2xl">
            <table class="w-full text-sm">
              <thead class="bg-slate-50 text-left text-slate-600 border-b border-slate-100">
                <tr>
                  <th class="px-5 py-3.5 font-bold">Operador</th>
                  <th class="px-5 py-3.5 font-bold">Email</th>
                  <th class="px-5 py-3.5 font-bold text-right">Acciones</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr v-if="loading && usuarios.length === 0">
                  <td colspan="3" class="px-5 py-6 text-slate-500 text-center">Cargando operadores...</td>
                </tr>
                <tr v-else-if="usuarios.length === 0">
                  <td colspan="3" class="px-5 py-6 text-slate-500 text-center">No hay operadores registrados aún.</td>
                </tr>
                <tr 
                  v-for="u in usuarios" 
                  :key="u.id" 
                  class="hover:bg-slate-50/50 transition-colors"
                >
                  <td class="px-5 py-3">
                    <div class="flex items-center gap-3">
                      <div class="h-9 w-9 bg-slate-900 text-white font-bold flex items-center justify-center rounded-xl text-sm shrink-0">
                        {{ u.nombre.charAt(0).toUpperCase() }}
                      </div>
                      <div class="min-w-0">
                        <p class="font-bold text-slate-800 truncate text-sm flex items-center gap-1.5">
                          {{ u.nombre }}
                          <span v-if="u.id === currentUser?.id" class="text-[10px] bg-indigo-50 text-indigo-700 border border-indigo-100 px-2 py-0.5 rounded-full font-semibold">
                            Tú (Activo)
                          </span>
                        </p>
                        <p class="text-[10px] text-slate-400">Registrado: {{ new Date(u.created_at).toLocaleDateString() }}</p>
                      </div>
                    </div>
                  </td>
                  <td class="px-5 py-3 text-slate-600 font-mono text-xs">{{ u.email }}</td>
                  <td class="px-5 py-3 text-right">
                    <div class="flex items-center justify-end gap-1">
                      <!-- Editar -->
                      <button 
                        @click="editUser(u)"
                        class="p-2 text-slate-400 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors"
                        title="Editar credenciales"
                      >
                        <Edit2 class="h-4 w-4" />
                      </button>
                      
                      <!-- Eliminar (Desactivado si es él mismo) -->
                      <button 
                        v-if="u.id !== currentUser?.id"
                        @click="showDeleteConfirm = u.id"
                        class="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                        title="Eliminar cuenta"
                      >
                        <Trash2 class="h-4 w-4" />
                      </button>
                      <button 
                        v-else
                        disabled
                        class="p-2 text-slate-300 cursor-not-allowed"
                        title="No puedes eliminar tu propio usuario"
                      >
                        <Trash2 class="h-4 w-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- MODAL DE CONFIRMACIÓN DE ELIMINAR USUARIO -->
  <div 
    v-if="showDeleteConfirm" 
    class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4"
  >
    <div 
      class="bg-white rounded-3xl p-6 max-w-sm w-full shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200"
      @click.stop
    >
      <h3 class="text-lg font-bold text-slate-900 mb-2 flex items-center gap-2">
        <ShieldAlert class="h-5 w-5 text-red-500" />
        ¿Eliminar operador?
      </h3>
      <p class="text-sm text-slate-500 mb-6">
        Esta acción es irreversible y removerá el acceso del operador de forma inmediata. La información del histórico vinculada a este usuario permanecerá asociada.
      </p>
      <div class="flex justify-end gap-2.5">
        <button 
          type="button" 
          @click="showDeleteConfirm = null"
          class="px-4 py-2.5 border border-slate-200 rounded-xl text-sm font-semibold hover:bg-slate-50 text-slate-700 transition-all active:scale-[0.98]"
        >
          Cancelar
        </button>
        <button 
          type="button" 
          @click="deleteUser(showDeleteConfirm)"
          class="px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white rounded-xl text-sm font-semibold transition-all active:scale-[0.98] shadow-md hover:shadow-red-600/20"
        >
          Sí, eliminar
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-2px);
}
</style>
