<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useSupabaseClient } from '#imports'
import { useBarcodeScanner } from '~/composables/useBarcodeScanner'

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
        <select 
          v-model="form.id_categoria" 
          required 
          class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm bg-white"
        >
          <option :value="null" disabled>Selecciona una categoría</option>
          <option v-for="cat in categorias" :key="cat.id" :value="cat.id">{{ cat.nombre }}</option>
        </select>
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
        <input 
          v-model="form.codigo_barras" 
          data-barcode-input="true"
          placeholder="Escanea con el lector o escribe el código"
          class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm font-mono"
        >
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
</template>
