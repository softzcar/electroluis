<script setup lang="ts">
const supabase = useSupabaseClient()

const repuestos = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const loadData = async () => {
  loading.value = true
  const { data, error } = await supabase.from('repuestos').select('*, categorias(nombre)').order('id', { ascending: false })
  if (error) errorMsg.value = error.message
  repuestos.value = data ?? []
  loading.value = false
}

onMounted(loadData)
</script>

<template>
  <div class="max-w-5xl mx-auto">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Repuestos</h1>

    <div class="bg-white p-5 rounded-lg shadow-sm mb-6">
      <RepuestoForm :show-cancel="false" @success="loadData" />
    </div>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow-sm overflow-x-auto border border-slate-100">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600 border-b border-slate-100">
          <tr>
            <th class="px-5 py-3 font-semibold">Nombre</th>
            <th class="px-5 py-3 font-semibold">Categoría</th>
            <th class="px-5 py-3 font-semibold">Cantidad</th>
            <th class="px-5 py-3 font-semibold">Ubicación</th>
            <th class="px-5 py-3 font-semibold">Código de barras</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-5 py-4 text-slate-500" colspan="5 font-semibold">Cargando repuestos...</td>
          </tr>
          <tr v-else-if="repuestos.length === 0">
            <td class="px-5 py-4 text-slate-500 text-center" colspan="5">No hay repuestos registrados aún.</td>
          </tr>
          <tr v-for="rep in repuestos" v-else :key="rep.id" class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
            <td class="px-5 py-3 font-medium text-slate-800">{{ rep.nombre }}</td>
            <td class="px-5 py-3 text-slate-600">{{ rep.categorias?.nombre || '—' }}</td>
            <td class="px-5 py-3">
              <span 
                class="px-2.5 py-1 rounded-full text-xs font-semibold"
                :class="rep.cantidad > 0 ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'"
              >
                {{ rep.cantidad }} uds
              </span>
            </td>
            <td class="px-5 py-3 text-slate-600">{{ rep.ubicacion || '—' }}</td>
            <td class="px-5 py-3 text-slate-500 font-mono text-xs">{{ rep.codigo_barras || '—' }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
