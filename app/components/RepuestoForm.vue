<script setup lang="ts">
import { ref, reactive, onMounted, watch, computed, type PropType } from 'vue'
import { useSupabaseClient } from '#imports'
import { useBarcodeScanner } from '~/composables/useBarcodeScanner'
import { Barcode, AlertCircle } from 'lucide-vue-next'

const emit = defineEmits<{
  (e: 'success', repuesto: any): void
  (e: 'cancel'): void
}>()

const props = defineProps({
  showCancel: {
    type: Boolean,
    default: true
  },
  repuesto: {
    type: Object as PropType<any>,
    default: null
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

const errors = reactive({
  nombre: '',
  id_categoria: '',
  cantidad: '',
  codigo_barras: ''
})

const categoriaErrorMsg = ref('')

// Para reactivación de repuesto eliminado
const showReactivateModal = ref(false)
const deletedRepuestoFound = ref<any | null>(null)

const isFormDisabled = computed(() => !!errors.codigo_barras || showReactivateModal.value)

const clearForm = () => {
  form.nombre = ''
  form.id_categoria = null
  form.cantidad = 0
  form.ubicacion = ''
  form.codigo_barras = ''
  errors.nombre = ''
  errors.id_categoria = ''
  errors.cantidad = ''
  errors.codigo_barras = ''
  errorMsg.value = ''
  showReactivateModal.value = false
  deletedRepuestoFound.value = null
  emit('cancel')
}

const loadCategories = async () => {
  const { data, error } = await supabase.from('categorias').select('*').is('deleted_at', null).order('nombre')
  if (!error) categorias.value = data ?? []
}

onMounted(loadCategories)

watch(() => props.repuesto, (newVal) => {
  if (newVal) {
    form.nombre = newVal.nombre || ''
    form.id_categoria = newVal.id_categoria || null
    form.cantidad = newVal.cantidad !== undefined ? newVal.cantidad : 0
    form.ubicacion = newVal.ubicacion || ''
    form.codigo_barras = newVal.codigo_barras || ''
  } else {
    form.nombre = ''
    form.id_categoria = null
    form.cantidad = 0
    form.ubicacion = ''
    form.codigo_barras = ''
  }
  errors.nombre = ''
  errors.id_categoria = ''
  errors.cantidad = ''
  errors.codigo_barras = ''
  errorMsg.value = ''
}, { immediate: true })

const createCategoria = async () => {
  categoriaErrorMsg.value = ''
  if (!newCategoriaNombre.value.trim()) {
    categoriaErrorMsg.value = 'El nombre de la categoría es obligatorio.'
    return
  }
  creatingCategoria.value = true
  const { data, error } = await supabase
    .from('categorias')
    .insert({ nombre: newCategoriaNombre.value.trim() })
    .select()
    .single()
  creatingCategoria.value = false
  if (error) {
    categoriaErrorMsg.value = error.message
    return
  }
  newCategoriaNombre.value = ''
  showCategoriaModal.value = false
  await loadCategories()
  if (data) {
    form.id_categoria = data.id
  }
}

// Buscar código de barras en la base de datos (incluyendo eliminados)
const checkBarcode = async (code: string) => {
  if (!code.trim()) {
    errors.codigo_barras = ''
    return
  }
  
  const { data, error } = await supabase
    .from('repuestos')
    .select('*, categorias(nombre)')
    .eq('codigo_barras', code.trim())
    .limit(1)
    
  if (error) {
    console.error('Error al validar código de barras:', error)
    return
  }
  
  if (data && data.length > 0) {
    const existing = data[0]
    
    // Si estamos editando y es el mismo repuesto, no hay problema
    if (props.repuesto && props.repuesto.id === existing.id) {
      errors.codigo_barras = ''
      return
    }
    
    if (existing.deleted_at) {
      // Repuesto marcado como eliminado
      deletedRepuestoFound.value = existing
      showReactivateModal.value = true
      errors.codigo_barras = ''
    } else {
      // Repuesto activo existente
      errors.codigo_barras = 'Este código de barras ya pertenece al repuesto activo: ' + existing.nombre
    }
  } else {
    errors.codigo_barras = ''
  }
}

const reactivateRepuesto = async () => {
  if (!deletedRepuestoFound.value) return
  
  loading.value = true
  const { data, error } = await supabase
    .from('repuestos')
    .update({ deleted_at: null })
    .eq('id', deletedRepuestoFound.value.id)
    .select('*, categorias(nombre)')
    .single()
    
  loading.value = false
  if (error) {
    errorMsg.value = error.message
    return
  }
  
  showReactivateModal.value = false
  const reactivatedItem = data
  deletedRepuestoFound.value = null
  
  emit('success', { reactivate: true, item: reactivatedItem })
}

// Escuchar el escáner de código de barras
useBarcodeScanner((code) => {
  form.codigo_barras = code
  checkBarcode(code)
})

const submit = async () => {
  errors.nombre = ''
  errors.id_categoria = ''
  errors.cantidad = ''
  errors.codigo_barras = ''
  
  await checkBarcode(form.codigo_barras)
  
  let hasError = false

  if (errors.codigo_barras || showReactivateModal.value) {
    hasError = true
  }
  if (!form.nombre.trim()) {
    errors.nombre = 'El nombre del repuesto es obligatorio.'
    hasError = true
  }
  if (!form.id_categoria) {
    errors.id_categoria = 'Debes seleccionar una categoría.'
    hasError = true
  }
  if (form.cantidad === null || form.cantidad === undefined || form.cantidad < 0) {
    errors.cantidad = 'El stock debe ser mayor o igual a 0.'
    hasError = true
  }

  if (hasError) return

  errorMsg.value = ''
  loading.value = true
  
  let data, error;
  
  if (props.repuesto && props.repuesto.id) {
    // Editar repuesto
    const response = await supabase
      .from('repuestos')
      .update({
        nombre: form.nombre.trim(),
        id_categoria: form.id_categoria,
        cantidad: form.cantidad,
        ubicacion: form.ubicacion || null,
        codigo_barras: form.codigo_barras || null
      })
      .eq('id', props.repuesto.id)
      .select('*, categorias(nombre)')
      .single()
    data = response.data
    error = response.error
  } else {
    // Crear repuesto
    const response = await supabase
      .from('repuestos')
      .insert({
        nombre: form.nombre.trim(),
        id_categoria: form.id_categoria,
        cantidad: form.cantidad,
        ubicacion: form.ubicacion || null,
        codigo_barras: form.codigo_barras || null
      })
      .select('*, categorias(nombre)')
      .single()
    data = response.data
    error = response.error
  }

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
  <div>
    <form @submit.prevent="submit" novalidate class="space-y-4">
      <h3 class="text-base font-bold text-slate-800 border-b border-slate-100 pb-2">
        {{ props.repuesto ? 'Editar Repuesto' : 'Registrar Nuevo Repuesto' }}
      </h3>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <!-- Código de barras (PRIMERO) -->
        <div class="sm:col-span-2">
          <label class="block text-sm font-semibold text-slate-700 mb-1">Código de barras</label>
          <div class="relative">
            <input 
              v-model="form.codigo_barras" 
              data-barcode-input="true"
              placeholder="Escanea con el lector o escribe el código"
              :class="[
                'w-full pl-3.5 pr-10 py-2 border rounded-xl focus:outline-none transition-all text-sm font-mono',
                errors.codigo_barras ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-900'
              ]"
              @blur="checkBarcode(form.codigo_barras)"
              @input="errors.codigo_barras = ''"
            >
            <Barcode class="absolute right-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
          </div>
          <Transition name="fade">
            <span v-if="errors.codigo_barras" class="text-xs text-red-600 mt-1.5 font-medium flex items-center gap-1">
              <AlertCircle :size="14" class="shrink-0" /> {{ errors.codigo_barras }}
            </span>
          </Transition>
        </div>

        <!-- Nombre del Repuesto -->
        <div>
          <label class="block text-sm font-semibold text-slate-700 mb-1">Nombre del Repuesto</label>
          <input 
            v-model="form.nombre" 
            :disabled="isFormDisabled"
            placeholder="Ej. Condensador 10uF, Tarjeta lógica"
            :class="[
              'w-full px-3.5 py-2 border rounded-xl focus:outline-none transition-all text-sm disabled:opacity-50 disabled:bg-slate-50',
              errors.nombre ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-950'
            ]"
            @input="errors.nombre = ''"
          >
          <Transition name="fade">
            <span v-if="errors.nombre" class="text-xs text-red-600 mt-1.5 font-medium flex items-center gap-1">
              <AlertCircle :size="14" class="shrink-0" /> {{ errors.nombre }}
            </span>
          </Transition>
        </div>
        
        <!-- Categoría -->
        <div>
          <label class="block text-sm font-semibold text-slate-700 mb-1">Categoría</label>
          <div class="flex gap-2">
            <select 
              v-model="form.id_categoria" 
              :disabled="isFormDisabled"
              :class="[
                'flex-1 px-3.5 py-2 border rounded-xl focus:outline-none transition-all text-sm bg-white disabled:opacity-50 disabled:bg-slate-50',
                errors.id_categoria ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-955'
              ]"
              @change="errors.id_categoria = ''"
            >
              <option :value="null" disabled>Selecciona una categoría</option>
              <option v-for="cat in categorias" :key="cat.id" :value="cat.id">{{ cat.nombre }}</option>
            </select>
            <button 
              type="button"
              :disabled="isFormDisabled"
              @click="showCategoriaModal = true; categoriaErrorMsg = ''; newCategoriaNombre = ''"
              class="px-3.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl border border-slate-200 font-bold transition-colors text-sm disabled:opacity-50 disabled:cursor-not-allowed"
              title="Agregar nueva categoría"
            >
              +
            </button>
          </div>
          <Transition name="fade">
            <span v-if="errors.id_categoria" class="text-xs text-red-600 mt-1.5 font-medium flex items-center gap-1">
              <AlertCircle :size="14" class="shrink-0" /> {{ errors.id_categoria }}
            </span>
          </Transition>
        </div>
        
        <!-- Cantidad Inicial / Stock -->
        <div>
          <label class="block text-sm font-semibold text-slate-700 mb-1">Stock</label>
          <input 
            v-model.number="form.cantidad" 
            :disabled="isFormDisabled"
            type="number" 
            min="0"
            placeholder="0"
            :class="[
              'w-full px-3.5 py-2 border rounded-xl focus:outline-none transition-all text-sm disabled:opacity-50 disabled:bg-slate-50',
              errors.cantidad ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-950'
            ]"
            @input="errors.cantidad = ''"
          >
          <Transition name="fade">
            <span v-if="errors.cantidad" class="text-xs text-red-600 mt-1.5 font-medium flex items-center gap-1">
              <AlertCircle :size="14" class="shrink-0" /> {{ errors.cantidad }}
            </span>
          </Transition>
        </div>
        
        <!-- Ubicación -->
        <div>
          <label class="block text-sm font-semibold text-slate-700 mb-1">Ubicación (Estante/Caja)</label>
          <input 
            v-model="form.ubicacion" 
            :disabled="isFormDisabled"
            placeholder="Ej. Pasillo A - Estante 2"
            class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm disabled:opacity-50 disabled:bg-slate-50"
          >
        </div>
      </div>

      <p v-if="errorMsg" class="text-xs text-red-600">{{ errorMsg }}</p>

      <div class="flex justify-end gap-2 pt-2">
        <button 
          type="button" 
          @click="clearForm"
          class="px-4 py-2 border border-slate-200 rounded-xl text-sm font-semibold hover:bg-slate-50 transition-colors text-slate-700"
        >
          Limpiar
        </button>
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
          :disabled="loading || isFormDisabled"
          class="px-4 py-2 bg-slate-950 text-white rounded-xl text-sm font-semibold hover:bg-slate-900 transition-colors disabled:opacity-50"
        >
          {{ loading ? 'Guardando...' : (props.repuesto ? 'Guardar Cambios' : 'Guardar Repuesto') }}
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
          :class="[
            'w-full px-3.5 py-2 border rounded-xl focus:outline-none transition-all text-sm mb-4',
            categoriaErrorMsg ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-950'
          ]"
          @keyup.enter="createCategoria"
          @input="categoriaErrorMsg = ''"
        >
        <Transition name="fade">
          <div v-if="categoriaErrorMsg" class="flex items-start gap-2.5 bg-red-50 border border-red-200 text-red-700 px-3.5 py-2.5 rounded-xl text-xs mb-4">
            <AlertCircle :size="16" class="shrink-0" />
            <span>{{ categoriaErrorMsg }}</span>
          </div>
        </Transition>
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

    <!-- MODAL DE REACTIVACIÓN DE REPUESTO ELIMINADO -->
    <div v-if="showReactivateModal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4">
      <div class="bg-white rounded-3xl p-6 max-w-md w-full shadow-2xl border border-slate-100" @click.stop>
        <h3 class="text-lg font-bold text-slate-900 mb-2 flex items-center gap-2">
          <AlertCircle class="h-5 w-5 text-indigo-600" />
          Repuesto eliminado detectado
        </h3>
        <p class="text-sm text-slate-600 mb-4">
          El código de barras ingresado pertenece a un repuesto previamente eliminado:
        </p>
        <div class="bg-slate-50 p-4 rounded-2xl text-xs space-y-2 mb-6 border border-slate-100">
          <p><span class="font-bold text-slate-700">Nombre:</span> {{ deletedRepuestoFound?.nombre }}</p>
          <p><span class="font-bold text-slate-700">Categoría:</span> {{ deletedRepuestoFound?.categorias?.nombre || '—' }}</p>
          <p><span class="font-bold text-slate-700">Código de barras:</span> <code class="font-mono">{{ deletedRepuestoFound?.codigo_barras }}</code></p>
          <p><span class="font-bold text-slate-700">Ubicación original:</span> {{ deletedRepuestoFound?.ubicacion || '—' }}</p>
        </div>
        <p class="text-sm text-slate-500 mb-6">
          ¿Deseas restaurar y reactivar este repuesto en el catálogo en lugar de crear uno nuevo?
        </p>
        <div class="flex justify-end gap-2.5">
          <button 
            type="button" 
            @click="showReactivateModal = false; form.codigo_barras = ''"
            class="px-4 py-2.5 border border-slate-200 rounded-xl text-sm font-semibold hover:bg-slate-50 text-slate-700 transition-all active:scale-[0.98]"
          >
            Cancelar
          </button>
          <button 
            type="button" 
            @click="reactivateRepuesto"
            :disabled="loading"
            class="px-4 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-sm font-semibold transition-all active:scale-[0.98] shadow-md shadow-indigo-600/10"
          >
            Sí, reactivar repuesto
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(-2px);
}
</style>
