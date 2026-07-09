<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useSupabaseClient } from '#imports'

const supabase = useSupabaseClient()

const marcas = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const form = reactive({
  nombre: ''
})

const loadData = async () => {
  loading.value = true
  const { data, error } = await supabase.from('marcas').select('*').order('nombre')
  if (error) errorMsg.value = error.message
  marcas.value = data ?? []
  loading.value = false
}

onMounted(loadData)

const submit = async () => {
  errorMsg.value = ''
  if (!form.nombre.trim()) return

  const { error } = await supabase.from('marcas').insert({ nombre: form.nombre.trim() })
  if (error) {
    errorMsg.value = error.message
    return
  }
  form.nombre = ''
  await loadData()
}
</script>

<template>
  <div class="max-w-2xl mx-auto">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Marcas</h1>

    <form class="bg-white p-5 rounded-lg shadow-sm mb-6 flex flex-col sm:flex-row gap-4 sm:items-end" @submit.prevent="submit">
      <div class="flex-1">
        <label class="block text-sm font-medium text-slate-600 mb-1">Nombre de la Marca</label>
        <input 
          v-model="form.nombre" 
          required 
          placeholder="Ej. Motorola, Epson, Samsung"
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow"
        >
      </div>
      <button type="submit" class="w-full sm:w-auto bg-slate-900 hover:bg-slate-800 text-white font-medium px-5 py-2.5 rounded-md transition-colors shadow-sm shrink-0">
        Agregar marca
      </button>
    </form>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow-sm overflow-x-auto border border-slate-100">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600 border-b border-slate-100">
          <tr>
            <th class="px-5 py-3 font-semibold">Nombre</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-5 py-4 text-slate-500">Cargando marcas...</td>
          </tr>
          <tr v-else-if="marcas.length === 0">
            <td class="px-5 py-4 text-slate-500 text-center">No hay marcas registradas aún.</td>
          </tr>
          <tr v-for="marca in marcas" :key="marca.id" class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
            <td class="px-5 py-3 font-medium text-slate-800">{{ marca.nombre }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
