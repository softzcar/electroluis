<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useSupabaseClient } from '#imports'
import { useBarcodeScanner } from '~/composables/useBarcodeScanner'
import { Barcode } from 'lucide-vue-next'

const emit = defineEmits<{
  (e: 'success', repuesto: any): void
  (e: 'cancel'): void
}>()

const props = defineProps({
  showCancel: {
    type: Boolean,
    default: true
  }
})

const supabase = useSupabaseClient()
const loading = ref(false)
const errorMsg = ref('')
const categorias = ref<any[]>([])
const showCategoriaModal = ref(false)
const newCategoriaNombre = ref('')
const creatingCategoria = ref(false)

const form = reactive({
  nombre: '',
  id_categoria: null as number | null,
  cantidad: 0,
  ubicacion: '',
  codigo_barras: ''
})

const loadCategories = async () => {
  const { data, error } = await supabase.from('categorias').select('*').order('nombre')
  if (!error) categorias.value = data ?? []
}

onMounted(loadCategories)

const createCategoria = async () => {
  if (!newCategoriaNombre.value.trim()) return
  creatingCategoria.value = true
  const { data, error } = await supabase
    .from('categorias')
    .insert({ nombre: newCategoriaNombre.value.trim() })
    .select()
    .single()
  creatingCategoria.value = false
  if (error) {
    alert(error.message)
    return
  }
  newCategoriaNombre.value = ''
  showCategoriaModal.value = false
  await loadCategories()
  if (data) {
    form.id_categoria = data.id
  }
}

// Escuchar el escáner de código de barras cuando el formulario esté visible
useBarcodeScanner((code) => {
  form.codigo_barras = code
})

const submit = async () => {
  errorMsg.value = ''
  loading.value = true
  
  const { data, error } = await supabase
    .from('repuestos')
    .insert({
      nombre: form.nombre,
      id_categoria: form.id_categoria,
      cantidad: form.cantidad,
      ubicacion: form.ubicacion || null,
      codigo_barras: form.codigo_barras || null
    })
    .select('*, categorias(nombre)')
    .single()

  loading.value = false

  if (error) {
    errorMsg.value = error.message
    return
  }

  // Resetear formulario
  form.nombre = ''
  form.id_categoria = null
  form.cantidad = 0
  form.ubicacion = ''
  form.codigo_barras = ''

  emit('success', data)
}
</script>

<template>
  <form @submit.prevent="submit" class="space-y-4">
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <div>
        <label class="block text-sm font-semibold text-slate-700 mb-1">Nombre del Repuesto</label>
        <input 
          v-model="form.nombre" 
          required 
          placeholder="Ej. Condensador 10uF, Tarjeta lógica"
          class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
        >
      </div>
      
      <div>
        <label class="block text-sm font-semibold text-slate-700 mb-1">Categoría</label>
        <div class="flex gap-2">
          <select 
            v-model="form.id_categoria" 
            required 
            class="flex-1 px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm bg-white"
          >
            <option :value="null" disabled>Selecciona una categoría</option>
            <option v-for="cat in categorias" :key="cat.id" :value="cat.id">{{ cat.nombre }}</option>
          </select>
          <button 
            type="button"
            @click="showCategoriaModal = true"
            class="px-3.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl border border-slate-200 font-bold transition-colors text-sm"
            title="Agregar nueva categoría"
          >
            +
          </button>
        </div>
      </div>
      
      <div>
        <label class="block text-sm font-semibold text-slate-700 mb-1">Cantidad Inicial</label>
        <input 
          v-model.number="form.cantidad" 
          type="number" 
          min="0"
          required
          placeholder="0"
          class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
        >
      </div>
      
      <div>
        <label class="block text-sm font-semibold text-slate-700 mb-1">Ubicación (Estante/Caja)</label>
        <input 
          v-model="form.ubicacion" 
          placeholder="Ej. Pasillo A - Estante 2"
          class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
        >
      </div>

      <div class="sm:col-span-2">
        <label class="block text-sm font-semibold text-slate-700 mb-1">Código de barras</label>
        <div class="relative">
          <input 
            v-model="form.codigo_barras" 
            data-barcode-input="true"
            placeholder="Escanea con el lector o escribe el código"
            class="w-full pl-3.5 pr-10 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm font-mono"
          >
          <Barcode class="absolute right-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
        </div>
      </div>
    </div>

    <p v-if="errorMsg" class="text-xs text-red-600">{{ errorMsg }}</p>

    <div class="flex justify-end gap-2 pt-2">
      <button 
        v-if="showCancel"
        type="button" 
        @click="emit('cancel')"
        class="px-4 py-2 border border-slate-200 rounded-xl text-sm font-semibold hover:bg-slate-50 transition-colors"
      >
        Cancelar
      </button>
      <button 
        type="submit" 
        :disabled="loading"
        class="px-4 py-2 bg-slate-950 text-white rounded-xl text-sm font-semibold hover:bg-slate-900 transition-colors disabled:opacity-50"
      >
        {{ loading ? 'Guardando...' : 'Guardar Repuesto' }}
      </button>
    </div>
  </form>

  <!-- MODAL INLINE: Crear Nueva Categoría -->
  <div v-if="showCategoriaModal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4">
    <div class="bg-white rounded-2xl p-6 max-w-sm w-full shadow-xl border border-slate-100" @click.stop>
      <h3 class="text-lg font-bold text-slate-800 mb-4">Agregar Nueva Categoría</h3>
      <input 
        v-model="newCategoriaNombre"
        placeholder="Nombre de la categoría (ej. Pantallas, Sensores)"
        class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm mb-4"
        @keyup.enter="createCategoria"
      >
      <div class="flex justify-end gap-2">
        <button 
          type="button" 
          @click="showCategoriaModal = false"
          class="px-4 py-2 border border-slate-200 rounded-xl text-sm font-semibold hover:bg-slate-50 transition-colors"
        >
          Cancelar
        </button>
        <button 
          type="button" 
          @click="createCategoria"
          :disabled="creatingCategoria"
          class="px-4 py-2 bg-slate-950 text-white rounded-xl text-sm font-semibold hover:bg-slate-900 transition-colors disabled:opacity-50"
        >
          Guardar
        </button>
      </div>
    </div>
  </div>
</template>
