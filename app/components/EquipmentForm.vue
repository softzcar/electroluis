<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useSupabaseClient } from '#imports'

const emit = defineEmits<{
  (e: 'success', equipment: any): void
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
  marca: '',
  modelo: ''
})

const submit = async () => {
  errorMsg.value = ''
  loading.value = true
  
  const { data, error } = await supabase
    .from('equipos')
    .insert({
      marca: form.marca,
      modelo: form.modelo
    })
    .select()
    .single()

  loading.value = false

  if (error) {
    errorMsg.value = error.message
    return
  }

  // Reset form
  form.marca = ''
  form.modelo = ''

  emit('success', data)
}
</script>

<template>
  <form @submit.prevent="submit" class="space-y-4">
    <div>
      <label class="block text-sm font-semibold text-slate-700 mb-1">Marca</label>
      <input 
        v-model="form.marca" 
        required 
        placeholder="Ej. Samsung, Whirlpool"
        class="w-full px-3.5 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
      >
    </div>
    
    <div>
      <label class="block text-sm font-semibold text-slate-700 mb-1">Modelo</label>
      <input 
        v-model="form.modelo" 
        required 
        placeholder="Ej. WF22B6300AW"
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
        {{ loading ? 'Guardando...' : 'Guardar Equipo' }}
      </button>
    </div>
  </form>
</template>
