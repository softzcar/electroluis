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
  <div>
    <h1 class="text-2xl font-semibold text-slate-800 mb-4">Clientes</h1>

    <form class="bg-white p-4 rounded-lg shadow mb-6 grid grid-cols-3 gap-3" @submit.prevent="submit">
      <div>
        <label class="block text-sm text-slate-600 mb-1">Nombre</label>
        <input v-model="form.nombre" required class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <div>
        <label class="block text-sm text-slate-600 mb-1">Telefono</label>
        <input v-model="form.telefono" class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <div>
        <label class="block text-sm text-slate-600 mb-1">Ubicacion</label>
        <input v-model="form.ubicacion_geografica" class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <div class="col-span-3 flex justify-end">
        <button type="submit" class="bg-slate-900 text-white px-4 py-2 rounded-md">Agregar cliente</button>
      </div>
    </form>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600">
          <tr>
            <th class="px-4 py-2">Nombre</th>
            <th class="px-4 py-2">Telefono</th>
            <th class="px-4 py-2">Ubicacion</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-4 py-3" colspan="3">Cargando...</td>
          </tr>
          <tr v-for="cli in clientes" v-else :key="cli.id" class="border-t border-slate-100">
            <td class="px-4 py-2">{{ cli.nombre }}</td>
            <td class="px-4 py-2">{{ cli.telefono }}</td>
            <td class="px-4 py-2">{{ cli.ubicacion_geografica }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
