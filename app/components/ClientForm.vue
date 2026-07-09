<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useSupabaseClient } from '#imports'

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

const submit = async () => {
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
  <form @submit.prevent="submit" class="space-y-4">
    <div>
      <label class="block text-sm font-semibold text-slate-700 mb-1">Nombre</label>
      <input 
        v-model="form.nombre" 
        required 
        placeholder="Ej. Juan Pérez"
        class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
      >
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
