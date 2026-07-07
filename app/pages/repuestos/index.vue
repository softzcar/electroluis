<script setup lang="ts">
const supabase = useSupabaseClient()

const repuestos = ref<any[]>([])
const categorias = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const form = reactive({
  nombre: '',
  id_categoria: null as number | null,
  cantidad: 0,
  ubicacion: '',
  codigo_barras: ''
})

const loadData = async () => {
  loading.value = true
  const [{ data: r, error: rErr }, { data: c, error: cErr }] = await Promise.all([
    supabase.from('repuestos').select('*, categorias(nombre)').order('id', { ascending: false }),
    supabase.from('categorias').select('*').order('nombre')
  ])
  if (rErr) errorMsg.value = rErr.message
  if (cErr) errorMsg.value = cErr.message
  repuestos.value = r ?? []
  categorias.value = c ?? []
  loading.value = false
}

onMounted(loadData)

// Cuando el lector de codigo de barras dispara una lectura, se completa el
// campo del formulario automaticamente.
useBarcodeScanner((code) => {
  form.codigo_barras = code
})

const submit = async () => {
  errorMsg.value = ''
  const { error } = await supabase.from('repuestos').insert({
    nombre: form.nombre,
    id_categoria: form.id_categoria,
    cantidad: form.cantidad,
    ubicacion: form.ubicacion || null,
    codigo_barras: form.codigo_barras || null
  })
  if (error) {
    errorMsg.value = error.message
    return
  }
  form.nombre = ''
  form.id_categoria = null
  form.cantidad = 0
  form.ubicacion = ''
  form.codigo_barras = ''
  await loadData()
}
</script>

<template>
  <div>
    <h1 class="text-2xl font-semibold text-slate-800 mb-4">Repuestos</h1>

    <form class="bg-white p-4 rounded-lg shadow mb-6 grid grid-cols-2 gap-3" @submit.prevent="submit">
      <div>
        <label class="block text-sm text-slate-600 mb-1">Nombre</label>
        <input v-model="form.nombre" required class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <div>
        <label class="block text-sm text-slate-600 mb-1">Categoria</label>
        <select v-model="form.id_categoria" required class="w-full px-3 py-2 border border-slate-300 rounded-md">
          <option v-for="cat in categorias" :key="cat.id" :value="cat.id">{{ cat.nombre }}</option>
        </select>
      </div>
      <div>
        <label class="block text-sm text-slate-600 mb-1">Cantidad</label>
        <input v-model.number="form.cantidad" type="number" min="0" class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <div>
        <label class="block text-sm text-slate-600 mb-1">Ubicacion</label>
        <input v-model="form.ubicacion" class="w-full px-3 py-2 border border-slate-300 rounded-md">
      </div>
      <div class="col-span-2">
        <label class="block text-sm text-slate-600 mb-1">Codigo de barras</label>
        <input
          v-model="form.codigo_barras"
          data-barcode-input="true"
          placeholder="Escanea o escribe el codigo"
          class="w-full px-3 py-2 border border-slate-300 rounded-md"
        >
      </div>
      <div class="col-span-2 flex justify-end">
        <button type="submit" class="bg-slate-900 text-white px-4 py-2 rounded-md">Agregar repuesto</button>
      </div>
    </form>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600">
          <tr>
            <th class="px-4 py-2">Nombre</th>
            <th class="px-4 py-2">Categoria</th>
            <th class="px-4 py-2">Cantidad</th>
            <th class="px-4 py-2">Ubicacion</th>
            <th class="px-4 py-2">Codigo de barras</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-4 py-3" colspan="5">Cargando...</td>
          </tr>
          <tr v-for="rep in repuestos" v-else :key="rep.id" class="border-t border-slate-100">
            <td class="px-4 py-2">{{ rep.nombre }}</td>
            <td class="px-4 py-2">{{ rep.categorias?.nombre }}</td>
            <td class="px-4 py-2">{{ rep.cantidad }}</td>
            <td class="px-4 py-2">{{ rep.ubicacion }}</td>
            <td class="px-4 py-2">{{ rep.codigo_barras }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
