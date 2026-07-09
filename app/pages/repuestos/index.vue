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
  <div class="max-w-5xl mx-auto">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Repuestos</h1>

    <form class="bg-white p-5 rounded-lg shadow-sm mb-6 grid grid-cols-1 sm:grid-cols-2 gap-4" @submit.prevent="submit">
      <div>
        <label class="block text-sm font-medium text-slate-600 mb-1">Nombre del Repuesto</label>
        <input 
          v-model="form.nombre" 
          required 
          placeholder="Ej. Condensador 10uF, Tarjeta lógica"
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow"
        >
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-600 mb-1">Categoría</label>
        <select 
          v-model="form.id_categoria" 
          required 
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow bg-white"
        >
          <option :value="null" disabled>Selecciona una categoría</option>
          <option v-for="cat in categorias" :key="cat.id" :value="cat.id">{{ cat.nombre }}</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-600 mb-1">Cantidad Inicial</label>
        <input 
          v-model.number="form.cantidad" 
          type="number" 
          min="0" 
          placeholder="0"
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow"
        >
      </div>
      <div>
        <label class="block text-sm font-medium text-slate-600 mb-1">Ubicación (Estante/Caja)</label>
        <input 
          v-model="form.ubicacion" 
          placeholder="Ej. Pasillo A - Estante 2"
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow"
        >
      </div>
      <div class="sm:col-span-2">
        <label class="block text-sm font-medium text-slate-600 mb-1">Código de barras</label>
        <input
          v-model="form.codigo_barras"
          data-barcode-input="true"
          placeholder="Escanea con el lector o escribe el código"
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow font-mono"
        >
      </div>
      <div class="sm:col-span-2 flex justify-end">
        <button type="submit" class="w-full sm:w-auto bg-slate-900 hover:bg-slate-800 text-white font-medium px-5 py-2.5 rounded-md transition-colors shadow-sm">
          Agregar repuesto
        </button>
      </div>
    </form>

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
            <td class="px-5 py-4 text-slate-500" colspan="5">Cargando repuestos...</td>
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
