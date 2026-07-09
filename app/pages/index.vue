<script setup lang="ts">
const supabase = useSupabaseClient()
const user = useSupabaseUser()

const movimientos = ref<any[]>([])
const clientes = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const form = reactive({
  id_cliente: null as number | null,
  descripcion: ''
})

const loadData = async () => {
  loading.value = true
  const [{ data: m, error: mErr }, { data: c, error: cErr }] = await Promise.all([
    supabase.from('movimientos').select('*, clientes(nombre)').order('id', { ascending: false }),
    supabase.from('clientes').select('*').order('nombre')
  ])
  if (mErr) errorMsg.value = mErr.message
  if (cErr) errorMsg.value = cErr.message
  movimientos.value = m ?? []
  clientes.value = c ?? []
  loading.value = false
}

onMounted(loadData)

const submit = async () => {
  errorMsg.value = ''
  const { error } = await supabase.from('movimientos').insert({
    id_cliente: form.id_cliente,
    id_user: user.value?.id,
    descripcion: form.descripcion || null
  })
  if (error) {
    errorMsg.value = error.message
    return
  }
  form.id_cliente = null
  form.descripcion = ''
  await loadData()
}
</script>

<template>
  <div class="max-w-5xl mx-auto">
    <h1 class="text-2xl font-bold text-slate-800 mb-2">Movimientos</h1>
    <p class="text-sm text-slate-500 mb-6">
      Registro de servicios prestados. La asociación de equipos y repuestos usados
      se agrega en un siguiente paso.
    </p>

    <form class="bg-white p-5 rounded-lg shadow-sm mb-6 grid grid-cols-1 sm:grid-cols-2 gap-4" @submit.prevent="submit">
      <div>
        <label class="block text-sm font-medium text-slate-600 mb-1">Cliente</label>
        <select 
          v-model="form.id_cliente" 
          required 
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow bg-white"
        >
          <option :value="null" disabled>Selecciona un cliente</option>
          <option v-for="cli in clientes" :key="cli.id" :value="cli.id">{{ cli.nombre }}</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-600 mb-1">Descripción del Servicio</label>
        <input 
          v-model="form.descripcion" 
          placeholder="Ej. Cambio de condensador y limpieza general"
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow"
        >
      </div>
      <div class="sm:col-span-2 flex justify-end">
        <button type="submit" class="w-full sm:w-auto bg-slate-900 hover:bg-slate-800 text-white font-medium px-5 py-2.5 rounded-md transition-colors shadow-sm">
          Registrar movimiento
        </button>
      </div>
    </form>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow-sm overflow-x-auto border border-slate-100">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600 border-b border-slate-100">
          <tr>
            <th class="px-5 py-3 font-semibold">Cliente</th>
            <th class="px-5 py-3 font-semibold">Descripción</th>
            <th class="px-5 py-3 font-semibold">Fecha</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-5 py-4 text-slate-500" colspan="3">Cargando movimientos...</td>
          </tr>
          <tr v-else-if="movimientos.length === 0">
            <td class="px-5 py-4 text-slate-500 text-center" colspan="3">No hay movimientos registrados aún.</td>
          </tr>
          <tr v-for="mov in movimientos" v-else :key="mov.id" class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
            <td class="px-5 py-3 font-medium text-slate-800">{{ mov.clientes?.nombre }}</td>
            <td class="px-5 py-3 text-slate-600">{{ mov.descripcion || '—' }}</td>
            <td class="px-5 py-3 text-slate-500">{{ new Date(mov.created_at).toLocaleString() }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
