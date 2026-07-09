<script setup lang="ts">
const supabase = useSupabaseClient()

const clientes = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const form = reactive({
  nombre: '',
  telefono: '',
  ubicacion_geografica: ''
})

const loadData = async () => {
  loading.value = true
  const { data, error } = await supabase.from('clientes').select('*').order('id', { ascending: false })
  if (error) errorMsg.value = error.message
  clientes.value = data ?? []
  loading.value = false
}

onMounted(loadData)

const submit = async () => {
  errorMsg.value = ''
  const { error } = await supabase.from('clientes').insert({
    nombre: form.nombre,
    telefono: form.telefono || null,
    ubicacion_geografica: form.ubicacion_geografica || null
  })
  if (error) {
    errorMsg.value = error.message
    return
  }
  form.nombre = ''
  form.telefono = ''
  form.ubicacion_geografica = ''
  await loadData()
}
</script>

<template>
  <div class="max-w-5xl mx-auto">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Clientes</h1>

    <form class="bg-white p-5 rounded-lg shadow-sm mb-6 grid grid-cols-1 sm:grid-cols-3 gap-4" @submit.prevent="submit">
      <div>
        <label class="block text-sm font-medium text-slate-600 mb-1">Nombre</label>
        <input 
          v-model="form.nombre" 
          required 
          placeholder="Ej. Juan Pérez"
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow"
        >
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-600 mb-1">Teléfono</label>
        <input 
          v-model="form.telefono" 
          placeholder="Ej. +56912345678"
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow"
        >
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-600 mb-1">Ubicación</label>
        <input 
          v-model="form.ubicacion_geografica" 
          placeholder="Ej. Av. Siempreviva 742"
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow"
        >
      </div>
      <div class="sm:col-span-3 flex justify-end">
        <button type="submit" class="w-full sm:w-auto bg-slate-900 hover:bg-slate-800 text-white font-medium px-5 py-2.5 rounded-md transition-colors shadow-sm">
          Agregar cliente
        </button>
      </div>
    </form>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow-sm overflow-x-auto border border-slate-100">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600 border-b border-slate-100">
          <tr>
            <th class="px-5 py-3 font-semibold">Nombre</th>
            <th class="px-5 py-3 font-semibold">Teléfono</th>
            <th class="px-5 py-3 font-semibold">Ubicación</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-5 py-4 text-slate-500" colspan="3">Cargando clientes...</td>
          </tr>
          <tr v-else-if="clientes.length === 0">
            <td class="px-5 py-4 text-slate-500 text-center" colspan="3">No hay clientes registrados aún.</td>
          </tr>
          <tr v-for="cli in clientes" v-else :key="cli.id" class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
            <td class="px-5 py-3 font-medium text-slate-800">{{ cli.nombre }}</td>
            <td class="px-5 py-3 text-slate-600">{{ cli.telefono || '—' }}</td>
            <td class="px-5 py-3 text-slate-600">{{ cli.ubicacion_geografica || '—' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
