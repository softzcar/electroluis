<script setup lang="ts">
const supabase = useSupabaseClient()

const equipos = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const loadData = async () => {
  loading.value = true
  const { data, error } = await supabase.from('equipos').select('*, marcas(nombre)').order('id', { ascending: false })
  if (error) errorMsg.value = error.message
  equipos.value = data ?? []
  loading.value = false
}

onMounted(loadData)
</script>

<template>
  <div class="max-w-5xl mx-auto">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Equipos</h1>

    <div class="bg-white p-5 rounded-lg shadow-sm mb-6">
      <EquipmentForm :show-cancel="false" @success="loadData" />
    </div>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow-sm overflow-x-auto border border-slate-100">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600 border-b border-slate-100">
          <tr>
            <th class="px-5 py-3 font-semibold">Marca</th>
            <th class="px-5 py-3 font-semibold">Modelo</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-5 py-4 text-slate-500" colspan="2">Cargando equipos...</td>
          </tr>
          <tr v-else-if="equipos.length === 0">
            <td class="px-5 py-4 text-slate-500 text-center" colspan="2">No hay equipos registrados aún.</td>
          </tr>
          <tr v-for="eq in equipos" v-else :key="eq.id" class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
            <td class="px-5 py-3 font-medium text-slate-800">{{ eq.marcas?.nombre }}</td>
            <td class="px-5 py-3 text-slate-600">{{ eq.modelo }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
