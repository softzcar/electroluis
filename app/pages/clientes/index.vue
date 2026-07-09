<script setup lang="ts">
const supabase = useSupabaseClient()

const clientes = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const loadData = async () => {
  loading.value = true
  const { data, error } = await supabase.from('clientes').select('*').order('id', { ascending: false })
  if (error) errorMsg.value = error.message
  clientes.value = data ?? []
  loading.value = false
}

onMounted(loadData)
</script>

<template>
  <div class="max-w-5xl mx-auto">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Clientes</h1>

    <div class="bg-white p-5 rounded-lg shadow-sm mb-6">
      <ClientForm :show-cancel="false" @success="loadData" />
    </div>

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
