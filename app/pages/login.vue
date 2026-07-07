<script setup lang="ts">
definePageMeta({ layout: false })

const supabase = useSupabaseClient()
const router = useRouter()

const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

const onSubmit = async () => {
  error.value = ''
  loading.value = true
  const { error: signInError } = await supabase.auth.signInWithPassword({
    email: email.value,
    password: password.value
  })
  loading.value = false
  if (signInError) {
    error.value = 'Credenciales invalidas'
    return
  }
  router.push('/')
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-slate-100">
    <form class="w-full max-w-sm bg-white p-8 rounded-lg shadow" @submit.prevent="onSubmit">
      <h1 class="text-xl font-semibold mb-6 text-slate-800">electroluis</h1>

      <label class="block text-sm text-slate-600 mb-1" for="email">Correo</label>
      <input
        id="email"
        v-model="email"
        type="email"
        required
        class="w-full mb-4 px-3 py-2 border border-slate-300 rounded-md"
      >

      <label class="block text-sm text-slate-600 mb-1" for="password">Contrasena</label>
      <input
        id="password"
        v-model="password"
        type="password"
        required
        class="w-full mb-4 px-3 py-2 border border-slate-300 rounded-md"
      >

      <p v-if="error" class="text-sm text-red-600 mb-4">{{ error }}</p>

      <button
        type="submit"
        :disabled="loading"
        class="w-full bg-slate-900 text-white py-2 rounded-md disabled:opacity-50"
      >
        {{ loading ? 'Ingresando...' : 'Ingresar' }}
      </button>
    </form>
  </div>
</template>
