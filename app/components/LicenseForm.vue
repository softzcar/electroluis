<script setup lang="ts">
import { ref, reactive, watch, computed, type PropType } from 'vue'
import { useSupabaseClient } from '#imports'
import { AlertCircle } from 'lucide-vue-next'

const emit = defineEmits<{
  (e: 'success', license: any): void
  (e: 'cancel'): void
}>()

const props = defineProps({
  showCancel: {
    type: Boolean,
    default: true
  },
  license: {
    type: Object as PropType<any>,
    default: null
  }
})

const supabase = useSupabaseClient()
const loading = ref(false)
const errorMsg = ref('')

const form = reactive({
  nombre: ''
})

const errors = reactive({
  nombre: ''
})

const showReactivateConfirm = ref(false)
const reactivateCandidate = ref<any>(null)

const isFormDisabled = computed(() => !!reactivateCandidate.value)

const clearForm = () => {
  form.nombre = ''
  errors.nombre = ''
  errorMsg.value = ''
  showReactivateConfirm.value = false
  reactivateCandidate.value = null
  emit('cancel')
}

watch(() => props.license, (newVal) => {
  if (newVal) {
    form.nombre = newVal.nombre || ''
  } else {
    form.nombre = ''
  }
  errors.nombre = ''
  errorMsg.value = ''
  showReactivateConfirm.value = false
  reactivateCandidate.value = null
}, { immediate: true })

const reactivateLicense = async () => {
  if (!reactivateCandidate.value) return
  
  loading.value = true
  errorMsg.value = ''
  
  const { data, error } = await supabase
    .from('licencias')
    .update({
      deleted_at: null
    })
    .eq('id', reactivateCandidate.value.id)
    .select()
    .single()
    
  loading.value = false
  showReactivateConfirm.value = false
  
  if (error) {
    errorMsg.value = error.message
    reactivateCandidate.value = null
    return
  }
  
  const reactivatedItem = data
  reactivateCandidate.value = null

  emit('success', reactivatedItem)
}

const submit = async () => {
  errors.nombre = ''
  
  if (!form.nombre.trim()) {
    errors.nombre = 'El nombre de la licencia es obligatorio.'
    return
  }

  errorMsg.value = ''
  loading.value = true

  // Check if a license with the same name already exists
  const name = form.nombre.trim()
  const { data: existing, error: checkError } = await supabase
    .from('licencias')
    .select('*')
    .ilike('nombre', name)

  if (checkError) {
    errorMsg.value = checkError.message
    loading.value = false
    return
  }

  // Filter out current editing license
  const filtered = (existing ?? []).filter((l: any) => !props.license?.id || l.id !== props.license.id)

  if (filtered && filtered.length > 0) {
    const matched = filtered[0]
    if (matched.deleted_at) {
      if (!props.license?.id) {
        loading.value = false
        reactivateCandidate.value = matched
        showReactivateConfirm.value = true
      } else {
        errors.nombre = `Esta licencia ya existe en los registros eliminados.`
        loading.value = false
      }
      return
    } else {
      errors.nombre = `Esta licencia ya está registrada.`
      loading.value = false
      return
    }
  }
  
  let data, error;
  
  if (props.license && props.license.id) {
    // Editar licencia
    const response = await supabase
      .from('licencias')
      .update({
        nombre: form.nombre.trim()
      })
      .eq('id', props.license.id)
      .select()
      .single()
    data = response.data
    error = response.error
  } else {
    // Crear nueva licencia
    const response = await supabase
      .from('licencias')
      .insert({
        nombre: form.nombre.trim()
      })
      .select()
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
  form.nombre = ''

  emit('success', data)
}
</script>

<template>
  <form @submit.prevent="submit" novalidate class="space-y-4">
    <h3 class="text-base font-bold text-slate-800 border-b border-slate-100 pb-2">
      {{ props.license ? 'Editar Licencia' : 'Registrar Nueva Licencia' }}
    </h3>

    <div>
      <label class="block text-sm font-semibold text-slate-700 mb-1">Nombre o Tipo de Licencia</label>
      <input 
        v-model="form.nombre" 
        :disabled="isFormDisabled"
        placeholder="Ej. Soporte 3D, Office 2024, Windows 11 Pro"
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
        {{ loading ? 'Guardando...' : (props.license ? 'Guardar Cambios' : 'Guardar Licencia') }}
      </button>
    </div>
  </form>

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
        Licencia eliminada encontrada
      </h3>
      <p class="text-sm text-slate-500 mb-4">
        Ya existe una licencia registrada con este nombre que fue eliminada anteriormente. ¿Deseas reactivarla?
      </p>
      
      <div class="bg-slate-50 p-4 rounded-2xl mb-6 text-xs space-y-2 border border-slate-100">
        <p class="text-slate-500 font-semibold uppercase tracking-wider text-[10px]">Datos de la licencia guardada:</p>
        <p class="text-slate-800"><span class="font-bold">Nombre:</span> {{ reactivateCandidate.nombre }}</p>
        <p v-if="reactivateCandidate.deleted_at" class="text-slate-400 italic">Eliminada el: {{ new Date(reactivateCandidate.deleted_at).toLocaleString() }}</p>
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
          @click="reactivateLicense"
          class="px-4 py-2.5 bg-slate-900 hover:bg-slate-850 text-white rounded-xl text-sm font-semibold transition-all active:scale-[0.98]"
        >
          Sí, reactivar licencia
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
