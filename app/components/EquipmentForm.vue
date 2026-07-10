<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
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
  const { data, error } = await supabase.from('marcas').select('*').order('nombre')
  if (!error) marcas.value = data ?? []
}

onMounted(loadMarcas)

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
  
  const { data, error } = await supabase
    .from('equipos')
    .insert({
      id_marca: form.id_marca,
      modelo: form.modelo
    })
    .select('*, marcas(nombre)')
    .single()

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
        {{ loading ? 'Guardando...' : 'Guardar Equipo' }}
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
