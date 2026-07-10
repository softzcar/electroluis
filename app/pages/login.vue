<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useSupabaseClient } from '#imports'
import { Mail, Lock, ArrowLeft, AlertCircle, CheckCircle } from 'lucide-vue-next'

definePageMeta({ layout: false })

const supabase = useSupabaseClient()
const router = useRouter()

const email = ref('')
const password = ref('')
const error = ref('')
const success = ref('')
const loading = ref(false)
const isResetMode = ref(false)

const errors = reactive({
  email: '',
  password: ''
})

const toggleResetMode = () => {
  isResetMode.value = !isResetMode.value
  error.value = ''
  success.value = ''
  errors.email = ''
  errors.password = ''
}

const onSubmit = async () => {
  error.value = ''
  success.value = ''
  errors.email = ''
  errors.password = ''

  let hasError = false
  if (!email.value.trim()) {
    errors.email = 'El correo electrónico es obligatorio.'
    hasError = true
  }
  if (!isResetMode.value && !password.value) {
    errors.password = 'La contraseña es obligatoria.'
    hasError = true
  }
  if (hasError) return

  loading.value = true

  try {
    if (isResetMode.value) {
      // Solicitar correo de recuperación de contraseña
      const config = useRuntimeConfig()
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email.value.trim(), {
        redirectTo: `${config.public.siteUrl}/reset-password`
      })
      if (resetError) throw resetError
      success.value = 'Enlace enviado. Revisa tu correo electrónico para restablecer tu contraseña.'
      email.value = ''
    } else {
      // Iniciar sesión normal
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: email.value.trim(),
        password: password.value
      })
      if (signInError) throw signInError
      router.push('/')
    }
  } catch (err: any) {
    error.value = err.message || 'Ocurrió un error inesperado. Inténtalo de nuevo.'
  } finally {
    loading.value = false
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
          {{ isResetMode ? 'Restablece el acceso a tu cuenta' : 'Control de repuestos y servicio técnico' }}
        </p>
      </div>

      <form class="space-y-6" @submit.prevent="onSubmit" novalidate>
        <!-- Input de Correo -->
        <div>
          <label class="block text-xs font-semibold uppercase tracking-wider text-slate-500 mb-2" for="email">
            Correo Electrónico
          </label>
          <div class="relative">
            <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-slate-400">
              <Mail :size="18" />
            </span>
            <input
              id="email"
              v-model="email"
              type="email"
              placeholder="ejemplo@correo.com"
              :class="[
                'w-full pl-10 pr-4 py-2.5 border rounded-xl focus:outline-none transition-all text-slate-800 placeholder-slate-400 text-sm',
                errors.email ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-300 focus:ring-2 focus:ring-indigo-500'
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

        <!-- Input de Contraseña (oculto en modo recuperación) -->
        <div v-if="!isResetMode">
          <div class="flex justify-between items-center mb-2">
            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-500" for="password">
              Contraseña
            </label>
            <button
              type="button"
              class="text-xs font-medium text-indigo-600 hover:text-indigo-800 transition-colors"
              @click="toggleResetMode"
            >
              ¿Olvidaste tu contraseña?
            </button>
          </div>
          <div class="relative">
            <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-slate-400">
              <Lock :size="18" />
            </span>
            <input
              id="password"
              v-model="password"
              type="password"
              placeholder="••••••••"
              :class="[
                'w-full pl-10 pr-4 py-2.5 border rounded-xl focus:outline-none transition-all text-slate-800 placeholder-slate-400 text-sm',
                errors.password ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-300 focus:ring-2 focus:ring-indigo-500'
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

        <!-- Botón de Envío -->
        <button
          type="submit"
          :disabled="loading"
          class="w-full bg-gradient-to-r from-slate-900 to-indigo-950 hover:from-slate-800 hover:to-indigo-900 text-white font-medium py-3 rounded-xl shadow-lg hover:shadow-indigo-950/20 active:scale-[0.98] transition-all disabled:opacity-50 text-sm flex items-center justify-center gap-2"
        >
          <span>{{ loading ? 'Procesando...' : (isResetMode ? 'Enviar enlace de recuperación' : 'Iniciar Sesión') }}</span>
        </button>

        <!-- Volver a Iniciar Sesión (solo modo recuperación) -->
        <div v-if="isResetMode" class="text-center pt-2">
          <button
            type="button"
            class="inline-flex items-center gap-1.5 text-sm font-medium text-slate-600 hover:text-slate-900 transition-colors"
            @click="toggleResetMode"
          >
            <ArrowLeft :size="16" />
            <span>Volver a iniciar sesión</span>
          </button>
        </div>
      </form>
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
