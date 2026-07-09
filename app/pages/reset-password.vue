<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useSupabaseClient } from '#imports'
import { Lock, AlertCircle, CheckCircle, ArrowLeft } from 'lucide-vue-next'

definePageMeta({ layout: false })

const supabase = useSupabaseClient()
const router = useRouter()

const newPassword = ref('')
const confirmPassword = ref('')
const error = ref('')
const success = ref('')
const loading = ref(true)
const updating = ref(false)
const hasSession = ref(false)

onMounted(async () => {
  try {
    // Dar un momento al cliente Supabase para procesar el token de la URL (si viene de un redirect)
    // y comprobar si se ha establecido una sesión
    const { data: { session } } = await supabase.auth.getSession()
    
    if (session) {
      hasSession.value = true
    } else {
      error.value = 'El enlace de recuperación es inválido, ha expirado o ya fue utilizado.'
    }
  } catch (err: any) {
    error.value = err.message || 'Error al validar la sesión de recuperación.'
  } finally {
    loading.value = false
  }
})

const onSubmit = async () => {
  error.value = ''
  success.value = ''
  
  if (newPassword.value !== confirmPassword.value) {
    error.value = 'Las contraseñas no coinciden.'
    return
  }

  if (newPassword.value.length < 6) {
    error.value = 'La contraseña debe tener al menos 6 caracteres.'
    return
  }

  updating.value = true
  try {
    const { error: updateError } = await supabase.auth.updateUser({
      password: newPassword.value
    })
    
    if (updateError) throw updateError
    
    success.value = 'Tu contraseña se ha restablecido con éxito. Entrando a la aplicación...'
    
    // Redirigir al inicio después de 2.5 segundos
    setTimeout(() => {
      router.push('/')
    }, 2500)
  } catch (err: any) {
    error.value = err.message || 'Ocurrió un error al actualizar la contraseña.'
    updating.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-900 via-slate-950 to-indigo-950 p-4">
    <!-- Círculos de luz decorativos de fondo -->
    <div class="absolute top-1/4 left-1/4 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none"></div>
    <div class="absolute bottom-1/3 right-1/4 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl pointer-events-none"></div>

    <div class="w-full max-w-md bg-white/95 backdrop-blur-md border border-slate-200/50 shadow-2xl rounded-2xl p-8 relative z-10">
      <div class="text-center mb-8">
        <h1 class="text-3xl font-extrabold tracking-tight bg-gradient-to-r from-slate-900 to-indigo-800 bg-clip-text text-transparent">
          Medic Play
        </h1>
        <p class="text-sm text-slate-500 mt-2">
          Restablecer Contraseña
        </p>
      </div>

      <!-- Estado Cargando / Verificando enlace -->
      <div v-if="loading" class="text-center py-8 space-y-4">
        <div class="w-10 h-10 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin mx-auto"></div>
        <p class="text-sm text-slate-600 font-medium">Verificando enlace de recuperación...</p>
      </div>

      <!-- Formulario para Nueva Contraseña -->
      <form v-else-if="hasSession" class="space-y-6" @submit.prevent="onSubmit">
        <!-- Nueva Contraseña -->
        <div>
          <label class="block text-xs font-semibold uppercase tracking-wider text-slate-500 mb-2" for="password">
            Nueva Contraseña
          </label>
          <div class="relative">
            <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-slate-400">
              <Lock :size="18" />
            </span>
            <input
              id="password"
              v-model="newPassword"
              type="password"
              required
              placeholder="Mínimo 6 caracteres"
              class="w-full pl-10 pr-4 py-2.5 border border-slate-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all text-slate-800 placeholder-slate-400 text-sm"
            >
          </div>
        </div>

        <!-- Confirmar Contraseña -->
        <div>
          <label class="block text-xs font-semibold uppercase tracking-wider text-slate-500 mb-2" for="confirmPassword">
            Confirmar Contraseña
          </label>
          <div class="relative">
            <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-slate-400">
              <Lock :size="18" />
            </span>
            <input
              id="confirmPassword"
              v-model="confirmPassword"
              type="password"
              required
              placeholder="Repite la nueva contraseña"
              class="w-full pl-10 pr-4 py-2.5 border border-slate-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-all text-slate-800 placeholder-slate-400 text-sm"
            >
          </div>
        </div>

        <!-- Mensaje de Error -->
        <Transition name="fade">
          <div v-if="error" class="flex items-start gap-2.5 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm">
            <AlertCircle :size="18" class="shrink-0 mt-0.5" />
            <span>{{ error }}</span>
          </div>
        </Transition>

        <!-- Mensaje de Éxito -->
        <Transition name="fade">
          <div v-if="success" class="flex items-start gap-2.5 bg-emerald-50 border border-emerald-200 text-emerald-700 px-4 py-3 rounded-xl text-sm">
            <CheckCircle :size="18" class="shrink-0 mt-0.5" />
            <span>{{ success }}</span>
          </div>
        </Transition>

        <!-- Botón de Actualizar -->
        <button
          type="submit"
          :disabled="updating"
          class="w-full bg-gradient-to-r from-slate-900 to-indigo-950 hover:from-slate-800 hover:to-indigo-900 text-white font-medium py-3 rounded-xl shadow-lg hover:shadow-indigo-950/20 active:scale-[0.98] transition-all disabled:opacity-50 text-sm flex items-center justify-center gap-2"
        >
          <span>{{ updating ? 'Actualizando contraseña...' : 'Guardar nueva contraseña' }}</span>
        </button>
      </form>

      <!-- Estado: Enlace inválido / Sesión ausente -->
      <div v-else class="space-y-6">
        <div class="flex items-start gap-2.5 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm">
          <AlertCircle :size="18" class="shrink-0 mt-0.5" />
          <span>{{ error }}</span>
        </div>

        <div class="text-center pt-2">
          <NuxtLink
            to="/login"
            class="inline-flex items-center gap-1.5 text-sm font-medium text-slate-600 hover:text-slate-900 transition-colors"
          >
            <ArrowLeft :size="16" />
            <span>Volver al inicio de sesión</span>
          </NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
