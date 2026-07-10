<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useSupabaseClient } from '#imports'
import { AlertCircle } from 'lucide-vue-next'

const emit = defineEmits<{
  (e: 'success', client: any): void
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

const form = reactive({
  nombre: '',
  telefono: '',
  ubicacion_geografica: ''
})

const errors = reactive({
  nombre: ''
})

const submit = async () => {
  errors.nombre = ''
  
  if (!form.nombre.trim()) {
    errors.nombre = 'El nombre del cliente es obligatorio.'
    return
  }

  errorMsg.value = ''
  loading.value = true
  
  const { data, error } = await supabase
    .from('clientes')
    .insert({
      nombre: form.nombre,
      telefono: form.telefono || null,
      ubicacion_geografica: form.ubicacion_geografica || null
    })
    .select()
    .single()

  loading.value = false

  if (error) {
    errorMsg.value = error.message
    return
  }

  // Reset form
  form.nombre = ''
  form.telefono = ''
  form.ubicacion_geografica = ''

  emit('success', data)
}
</script>

<template>
  <form @submit.prevent="submit" novalidate class="space-y-4">
    <div>
      <label class="block text-sm font-semibold text-slate-700 mb-1">Nombre</label>
      <input 
        v-model="form.nombre" 
        placeholder="Ej. Juan Pérez"
        :class="[
          'w-full px-3.5 py-2 border rounded-xl focus:outline-none transition-all text-sm',
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
    
    <div>
      <label class="block text-sm font-semibold text-slate-700 mb-1">Teléfono</label>
      <input 
        v-model="form.telefono" 
        placeholder="Ej. +56912345678"
        class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
      >
    </div>
    
    <div>
      <label class="block text-sm font-semibold text-slate-700 mb-1">Ubicación</label>
      <input 
        v-model="form.ubicacion_geografica" 
        placeholder="Ej. Av. Siempreviva 742"
        class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
      >
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
        {{ loading ? 'Guardando...' : 'Guardar Cliente' }}
      </button>
    </div>
  </form>
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
