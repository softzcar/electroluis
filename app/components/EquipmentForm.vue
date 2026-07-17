<script setup lang="ts">
import { ref, reactive, onMounted, watch, type PropType } from 'vue'
import { useSupabaseClient } from '#imports'
import { AlertCircle } from 'lucide-vue-next'

const emit = defineEmits<{
  (e: 'success', equipment: any): void
  (e: 'cancel'): void
}>()

const props = defineProps({
  showCancel: {
    type: Boolean,
    default: true
  },
  equipment: {
    type: Object as PropType<any>,
    default: null
  }
})

const supabase = useSupabaseClient()
const loading = ref(false)
const errorMsg = ref('')

const marcas = ref<any[]>([])
const showMarcaModal = ref(false)
const newMarcaNombre = ref('')
const creatingMarca = ref(false)

const form = reactive({
  id_marca: null as number | null,
  modelo: ''
})

const errors = reactive({
  id_marca: '',
  modelo: ''
})

const brandErrorMsg = ref('')

const loadMarcas = async () => {
  const { data, error } = await supabase.from('marcas').select('*').is('deleted_at', null).order('nombre')
  if (!error) marcas.value = data ?? []
}

onMounted(loadMarcas)

const showReactivateConfirm = ref(false)
const reactivateCandidate = ref<any>(null)

watch(() => props.equipment, (newVal) => {
  if (newVal) {
    form.id_marca = newVal.id_marca || null
    form.modelo = newVal.modelo || ''
  } else {
    form.id_marca = null
    form.modelo = ''
  }
  errors.id_marca = ''
  errors.modelo = ''
  errorMsg.value = ''
  showReactivateConfirm.value = false
  reactivateCandidate.value = null
}, { immediate: true })

const createMarca = async () => {
  brandErrorMsg.value = ''
  if (!newMarcaNombre.value.trim()) {
    brandErrorMsg.value = 'El nombre de la marca es obligatorio.'
    return
  }
  creatingMarca.value = true
  const { data, error } = await supabase
    .from('marcas')
    .insert({ nombre: newMarcaNombre.value.trim() })
    .select()
    .single()
  creatingMarca.value = false
  if (error) {
    brandErrorMsg.value = error.message
    return
  }
  newMarcaNombre.value = ''
  showMarcaModal.value = false
  await loadMarcas()
  if (data) {
    form.id_marca = data.id
  }
}

const reactivateEquipment = async () => {
  if (!reactivateCandidate.value) return
  
  loading.value = true
  errorMsg.value = ''
  
  const { data, error } = await supabase
    .from('equipos')
    .update({
      deleted_at: null
    })
    .eq('id', reactivateCandidate.value.id)
    .select('*, marcas(nombre)')
    .single()
    
  loading.value = false
  showReactivateConfirm.value = false
  reactivateCandidate.value = null
  
  if (error) {
    errorMsg.value = error.message
    return
  }
  
  // Reset form
  form.id_marca = null
  form.modelo = ''

  emit('success', data)
}

const submit = async () => {
  errors.id_marca = ''
  errors.modelo = ''
  let hasError = false

  if (!form.id_marca) {
    errors.id_marca = 'Debes seleccionar una marca.'
    hasError = true
  }
  if (!form.modelo.trim()) {
    errors.modelo = 'El modelo del equipo es obligatorio.'
    hasError = true
  }

  if (hasError) return

  errorMsg.value = ''
  loading.value = true

  // Validar marca y modelo duplicado en eliminados (solo en creación)
  if (!props.equipment?.id && form.id_marca && form.modelo.trim()) {
    const { data: existingDeleted, error: checkError } = await supabase
      .from('equipos')
      .select('*, marcas(nombre)')
      .eq('id_marca', form.id_marca)
      .eq('modelo', form.modelo.trim())
      .not('deleted_at', 'is', null)
      .limit(1)

    if (checkError) {
      errorMsg.value = checkError.message
      loading.value = false
      return
    }

    if (existingDeleted && existingDeleted.length > 0) {
      loading.value = false
      reactivateCandidate.value = existingDeleted[0]
      showReactivateConfirm.value = true
      return
    }
  }
  
  let data, error;
  
  if (props.equipment && props.equipment.id) {
    // Editar equipo
    const response = await supabase
      .from('equipos')
      .update({
        id_marca: form.id_marca,
        modelo: form.modelo.trim()
      })
      .eq('id', props.equipment.id)
      .select('*, marcas(nombre)')
      .single()
    data = response.data
    error = response.error
  } else {
    // Crear equipo
    const response = await supabase
      .from('equipos')
      .insert({
        id_marca: form.id_marca,
        modelo: form.modelo.trim()
      })
      .select('*, marcas(nombre)')
      .single()
    data = response.data
    error = response.error
  }

  loading.value = false

  if (error) {
    errorMsg.value = error.message
    return
  }

  // Reset form
  form.id_marca = null
  form.modelo = ''

  emit('success', data)
}
</script>

<template>
  <form @submit.prevent="submit" novalidate class="space-y-4">
    <h3 class="text-base font-bold text-slate-800 border-b border-slate-100 pb-2">
      {{ props.equipment ? 'Editar Equipo' : 'Registrar Nuevo Equipo' }}
    </h3>

    <div>
      <label class="block text-sm font-semibold text-slate-700 mb-1">Marca</label>
      <div class="flex gap-2">
        <select 
          v-model="form.id_marca" 
          :class="[
            'flex-1 px-3.5 py-2 border rounded-xl focus:outline-none transition-all text-sm bg-white',
            errors.id_marca ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-950'
          ]"
          @change="errors.id_marca = ''"
        >
          <option :value="null" disabled>Selecciona una marca</option>
          <option v-for="m in marcas" :key="m.id" :value="m.id">{{ m.nombre }}</option>
        </select>
        <button 
          type="button"
          @click="showMarcaModal = true; brandErrorMsg = ''; newMarcaNombre = ''"
          class="px-3.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl border border-slate-200 font-bold transition-colors text-sm"
          title="Agregar nueva marca"
        >
          +
        </button>
      </div>
      <Transition name="fade">
        <span v-if="errors.id_marca" class="text-xs text-red-600 mt-1.5 font-medium flex items-center gap-1">
          <AlertCircle :size="14" class="shrink-0" /> {{ errors.id_marca }}
        </span>
      </Transition>
    </div>
    
    <div>
      <label class="block text-sm font-semibold text-slate-700 mb-1">Modelo</label>
      <input 
        v-model="form.modelo" 
        placeholder="Ej. WF22B6300AW"
        :class="[
          'w-full px-3.5 py-2 border rounded-xl focus:outline-none transition-all text-sm',
          errors.modelo ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-950'
        ]"
        @input="errors.modelo = ''"
      >
      <Transition name="fade">
        <span v-if="errors.modelo" class="text-xs text-red-600 mt-1.5 font-medium flex items-center gap-1">
          <AlertCircle :size="14" class="shrink-0" /> {{ errors.modelo }}
        </span>
      </Transition>
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
        {{ loading ? 'Guardando...' : (props.equipment ? 'Guardar Cambios' : 'Guardar Equipo') }}
      </button>
    </div>
  </form>

  <!-- MODAL INLINE: Crear Nueva Marca -->
  <div v-if="showMarcaModal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[60] flex items-center justify-center p-4">
    <div class="bg-white rounded-2xl p-6 max-w-sm w-full shadow-xl border border-slate-100" @click.stop>
      <h3 class="text-lg font-bold text-slate-800 mb-4">Agregar Nueva Marca</h3>
      <input 
        v-model="newMarcaNombre"
        placeholder="Nombre de la marca (ej. Epson)"
        :class="[
          'w-full px-3.5 py-2 border rounded-xl focus:outline-none transition-all text-sm mb-4',
          brandErrorMsg ? 'border-red-500 focus:ring-2 focus:ring-red-100 bg-red-50/20' : 'border-slate-200 focus:ring-2 focus:ring-slate-950'
        ]"
        @keyup.enter="createMarca"
        @input="brandErrorMsg = ''"
      >
      <Transition name="fade">
        <div v-if="brandErrorMsg" class="flex items-start gap-2.5 bg-red-50 border border-red-200 text-red-700 px-3.5 py-2.5 rounded-xl text-xs mb-4">
          <AlertCircle :size="16" class="shrink-0 mt-0.5" />
          <span>{{ brandErrorMsg }}</span>
        </div>
      </Transition>
      <div class="flex justify-end gap-2">
        <button 
          type="button" 
          @click="showMarcaModal = false"
          class="px-4 py-2 border border-slate-200 rounded-xl text-sm font-semibold hover:bg-slate-50 transition-colors"
        >
          Cancelar
        </button>
        <button 
          type="button" 
          @click="createMarca"
          :disabled="creatingMarca"
          class="px-4 py-2 bg-slate-950 text-white rounded-xl text-sm font-semibold hover:bg-slate-900 transition-colors disabled:opacity-50"
        >
          Guardar
        </button>
      </div>
    </div>
  </div>

  <!-- MODAL DE REACTIVACIÓN -->
  <div 
    v-if="showReactivateConfirm" 
    class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4"
  >
    <div 
      class="bg-white rounded-3xl p-6 max-w-md w-full shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200"
      @click.stop
    >
      <h3 class="text-lg font-bold text-slate-900 mb-2 flex items-center gap-2">
        <AlertCircle class="h-5 w-5 text-amber-500" />
        Equipo eliminado encontrado
      </h3>
      <p class="text-sm text-slate-500 mb-4">
        Ya existe un equipo registrado con esta marca y modelo que fue eliminado anteriormente. ¿Deseas reactivarlo?
      </p>
      
      <div class="bg-slate-50 p-4 rounded-2xl mb-6 text-xs space-y-2 border border-slate-100">
        <p class="text-slate-500 font-semibold uppercase tracking-wider text-[10px]">Datos del equipo guardado:</p>
        <p class="text-slate-800"><span class="font-bold">Marca:</span> {{ reactivateCandidate.marcas?.nombre }}</p>
        <p class="text-slate-800"><span class="font-bold">Modelo:</span> {{ reactivateCandidate.modelo }}</p>
        <p v-if="reactivateCandidate.deleted_at" class="text-slate-400 italic">Eliminado el: {{ new Date(reactivateCandidate.deleted_at).toLocaleString() }}</p>
      </div>

      <div class="flex justify-end gap-2.5">
        <button 
          type="button" 
          @click="showReactivateConfirm = false; reactivateCandidate = null"
          class="px-4 py-2.5 border border-slate-200 rounded-xl text-sm font-semibold hover:bg-slate-50 text-slate-700 transition-all active:scale-[0.98]"
        >
          Cancelar
        </button>
        <button 
          type="button" 
          @click="reactivateEquipment"
          class="px-4 py-2.5 bg-slate-900 hover:bg-slate-850 text-white rounded-xl text-sm font-semibold transition-all active:scale-[0.98]"
        >
          Sí, reactivar equipo
        </button>
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
