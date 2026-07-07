<script setup lang="ts">
const supabase = useSupabaseClient()

const equipos = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const form = reactive({
  marca: '',
  modelo: '',
  nro_serie: ''
})

const loadData = async () => {
  loading.value = true
  const { data, error } = await supabase.from('equipos').select('*').order('id', { ascending: false })
  if (error) errorMsg.value = error.message
  equipos.value = data ?? []
  loading.value = false
}

onMounted(loadData)

const submit = async () => {
  errorMsg.value = ''
  const { error } = await supabase.from('equipos').insert({
    marca: form.marca,
    modelo: form.modelo,
    nro_serie: form.nro_serie
  })
  if (error) {
    errorMsg.value = error.message
    return
  }
  form.marca = ''
  form.modelo = ''
  form.nro_serie = ''
  await loadData()
}
</script>

<template>
  <div>
    <h1 class="text-2xl font-semibold text-slate-800 mb-4">Equipos</h1>

    <form class="bg-white p-4 rounded-lg shadow mb-6 grid grid-cols-3 gap-3" @submit.prevent="submit">
      <div>
        <label class="block text-sm text-slate-600 mb-1">Marca</label>
        <input v-model="form.marca" required class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <div>
        <label class="block text-sm text-slate-600 mb-1">Modelo</label>
        <input v-model="form.modelo" required class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <div>
        <label class="block text-sm text-slate-600 mb-1">Numero de serie</label>
        <input v-model="form.nro_serie" required class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <div class="col-span-3 flex justify-end">
        <button type="submit" class="bg-slate-900 text-white px-4 py-2 rounded-md">Agregar equipo</button>
      </div>
    </form>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600">
          <tr>
            <th class="px-4 py-2">Marca</th>
            <th class="px-4 py-2">Modelo</th>
            <th class="px-4 py-2">Numero de serie</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-4 py-3" colspan="3">Cargando...</td>
          </tr>
          <tr v-for="eq in equipos" v-else :key="eq.id" class="border-t border-slate-100">
            <td class="px-4 py-2">{{ eq.marca }}</td>
            <td class="px-4 py-2">{{ eq.modelo }}</td>
            <td class="px-4 py-2">{{ eq.nro_serie }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
