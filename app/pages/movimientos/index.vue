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
  <div>
    <h1 class="text-2xl font-semibold text-slate-800 mb-4">Movimientos</h1>
    <p class="text-sm text-slate-500 mb-4">
      Registro de servicios prestados. La asociacion de equipos y repuestos usados
      se agrega en un siguiente paso.
    </p>

    <form class="bg-white p-4 rounded-lg shadow mb-6 grid grid-cols-2 gap-3" @submit.prevent="submit">
      <div>
        <label class="block text-sm text-slate-600 mb-1">Cliente</label>
        <select v-model="form.id_cliente" required class="w-full px-3 py-2 border border-slate-300 rounded-md">
          <option v-for="cli in clientes" :key="cli.id" :value="cli.id">{{ cli.nombre }}</option>
        </select>
      </div>
      <div>
        <label class="block text-sm text-slate-600 mb-1">Descripcion</label>
        <input v-model="form.descripcion" class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <div class="col-span-2 flex justify-end">
        <button type="submit" class="bg-slate-900 text-white px-4 py-2 rounded-md">Registrar movimiento</button>
      </div>
    </form>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600">
          <tr>
            <th class="px-4 py-2">Cliente</th>
            <th class="px-4 py-2">Descripcion</th>
            <th class="px-4 py-2">Fecha</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-4 py-3" colspan="3">Cargando...</td>
          </tr>
          <tr v-for="mov in movimientos" v-else :key="mov.id" class="border-t border-slate-100">
            <td class="px-4 py-2">{{ mov.clientes?.nombre }}</td>
            <td class="px-4 py-2">{{ mov.descripcion }}</td>
            <td class="px-4 py-2">{{ new Date(mov.created_at).toLocaleString() }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
