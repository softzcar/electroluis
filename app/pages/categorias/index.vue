<script setup lang="ts">
const supabase = useSupabaseClient()

const categorias = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const form = reactive({
  nombre: ''
})

const loadData = async () => {
  loading.value = true
  const { data, error } = await supabase.from('categorias').select('*').order('nombre')
  if (error) errorMsg.value = error.message
  categorias.value = data ?? []
  loading.value = false
}

onMounted(loadData)

const submit = async () => {
  errorMsg.value = ''
  const { error } = await supabase.from('categorias').insert({ nombre: form.nombre })
  if (error) {
    errorMsg.value = error.message
    return
  }
  form.nombre = ''
  await loadData()
}
</script>

<template>
  <div>
    <h1 class="text-2xl font-semibold text-slate-800 mb-4">Categorias</h1>

    <form class="bg-white p-4 rounded-lg shadow mb-6 flex gap-3 items-end" @submit.prevent="submit">
      <div class="flex-1">
        <label class="block text-sm text-slate-600 mb-1">Nombre</label>
        <input v-model="form.nombre" required class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <button type="submit" class="bg-slate-900 text-white px-4 py-2 rounded-md">Agregar categoria</button>
    </form>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600">
          <tr>
            <th class="px-4 py-2">Nombre</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-4 py-3">Cargando...</td>
          </tr>
          <tr v-for="cat in categorias" v-else :key="cat.id" class="border-t border-slate-100">
            <td class="px-4 py-2">{{ cat.nombre }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
