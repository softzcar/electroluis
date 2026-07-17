<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Edit2, Trash2, AlertCircle } from 'lucide-vue-next'

const supabase = useSupabaseClient()

const marcas = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const form = reactive({
  nombre: ''
})

const editingId = ref<number | null>(null)
const showDeleteConfirm = ref<number | null>(null)

const loadData = async () => {
  loading.value = true
  const { data, error } = await supabase
    .from('marcas')
    .select('*')
    .is('deleted_at', null)
    .order('nombre')
  if (error) errorMsg.value = error.message
  marcas.value = data ?? []
  loading.value = false
}

onMounted(loadData)

const showReactivateConfirm = ref(false)
const reactivateCandidate = ref<any>(null)

const startEdit = (marca: any) => {
  editingId.value = marca.id
  form.nombre = marca.nombre
  errorMsg.value = ''
  showReactivateConfirm.value = false
  reactivateCandidate.value = null
}

const cancelEdit = () => {
  editingId.value = null
  form.nombre = ''
  errorMsg.value = ''
  showReactivateConfirm.value = false
  reactivateCandidate.value = null
}

const reactivateBrand = async () => {
  if (!reactivateCandidate.value) return
  
  errorMsg.value = ''
  loading.value = true
  
  const { error } = await supabase
    .from('marcas')
    .update({
      nombre: form.nombre.trim(),
      deleted_at: null
    })
    .eq('id', reactivateCandidate.value.id)
    
  loading.value = false
  showReactivateConfirm.value = false
  reactivateCandidate.value = null
  
  if (error) {
    errorMsg.value = error.message
    return
  }
  
  form.nombre = ''
  await loadData()
}

const submit = async () => {
  errorMsg.value = ''
  if (!form.nombre.trim()) return

  if (editingId.value) {
    const { error } = await supabase
      .from('marcas')
      .update({ nombre: form.nombre.trim() })
      .eq('id', editingId.value)
    if (error) {
      errorMsg.value = error.message
      return
    }
    cancelEdit()
  } else {
    // Validar nombre duplicado en eliminados (solo en creación)
    const { data: existingDeleted, error: checkError } = await supabase
      .from('marcas')
      .select('*')
      .ilike('nombre', form.nombre.trim())
      .not('deleted_at', 'is', null)
      .limit(1)

    if (checkError) {
      errorMsg.value = checkError.message
      return
    }

    if (existingDeleted && existingDeleted.length > 0) {
      reactivateCandidate.value = existingDeleted[0]
      showReactivateConfirm.value = true
      return
    }

    const { error } = await supabase
      .from('marcas')
      .insert({ nombre: form.nombre.trim() })
    if (error) {
      errorMsg.value = error.message
      return
    }
    form.nombre = ''
  }
  await loadData()
}

const deleteRecord = async (id: number) => {
  errorMsg.value = ''
  const { error } = await supabase
    .from('marcas')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', id)
  if (error) {
    errorMsg.value = error.message
  } else {
    showDeleteConfirm.value = null
    await loadData()
  }
}
</script>

<template>
  <div class="max-w-2xl mx-auto">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Marcas</h1>

    <form class="bg-white p-5 rounded-lg shadow-sm mb-6 flex flex-col sm:flex-row gap-4 sm:items-end" @submit.prevent="submit">
      <div class="flex-1">
        <label class="block text-sm font-medium text-slate-600 mb-1">
          {{ editingId ? 'Editar Nombre de la Marca' : 'Nombre de la Marca' }}
        </label>
        <input 
          v-model="form.nombre" 
          required 
          placeholder="Ej. Motorola, Epson, Samsung"
          class="w-full px-3 py-2 border border-slate-300 rounded-md focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow"
        >
      </div>
      <div class="flex gap-2">
        <button type="submit" class="w-full sm:w-auto bg-slate-900 hover:bg-slate-800 text-white font-medium px-5 py-2.5 rounded-md transition-colors shadow-sm shrink-0">
          {{ editingId ? 'Guardar' : 'Agregar marca' }}
        </button>
        <button v-if="editingId" type="button" @click="cancelEdit" class="w-full sm:w-auto bg-slate-100 hover:bg-slate-200 text-slate-700 font-medium px-5 py-2.5 rounded-md transition-colors border border-slate-200 shrink-0">
          Cancelar
        </button>
      </div>
    </form>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow-sm overflow-x-auto border border-slate-100">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600 border-b border-slate-100">
          <tr>
            <th class="px-5 py-3 font-semibold">Nombre</th>
            <th class="px-5 py-3 font-semibold text-right">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-5 py-4 text-slate-500" colspan="2">Cargando marcas...</td>
          </tr>
          <tr v-else-if="marcas.length === 0">
            <td class="px-5 py-4 text-slate-500 text-center" colspan="2">No hay marcas registradas aún.</td>
          </tr>
          <tr v-for="marca in marcas" :key="marca.id" v-else class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
            <td class="px-5 py-3 font-medium text-slate-800">{{ marca.nombre }}</td>
            <td class="px-5 py-3 text-right">
              <div class="flex items-center justify-end gap-1">
                <button 
                  @click="startEdit(marca)"
                  class="p-2 text-slate-400 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors"
                  title="Editar marca"
                >
                  <Edit2 class="h-4 w-4" />
                </button>
                <button 
                  @click="showDeleteConfirm = marca.id"
                  class="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                  title="Eliminar marca"
                >
                  <Trash2 class="h-4 w-4" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>

  <!-- MODAL DE CONFIRMACIÓN DE ELIMINAR -->
  <div 
    v-if="showDeleteConfirm" 
    class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4"
  >
    <div 
      class="bg-white rounded-3xl p-6 max-w-sm w-full shadow-2xl border border-slate-100"
      @click.stop
    >
      <h3 class="text-lg font-bold text-slate-900 mb-2 flex items-center gap-2">
        <AlertCircle class="h-5 w-5 text-red-500" />
        ¿Eliminar marca?
      </h3>
      <p class="text-sm text-slate-500 mb-6">
        Esta acción marcará la marca como eliminada. Los equipos asociados a esta marca seguirán existiendo en el histórico de movimientos.
      </p>
      <div class="flex justify-end gap-2.5">
        <button 
          type="button" 
          @click="showDeleteConfirm = null"
          class="px-4 py-2.5 border border-slate-200 rounded-xl text-sm font-semibold hover:bg-slate-50 text-slate-700 transition-all active:scale-[0.98]"
        >
          Cancelar
        </button>
        <button 
          type="button" 
          @click="deleteRecord(showDeleteConfirm)"
          class="px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white rounded-xl text-sm font-semibold transition-all active:scale-[0.98]"
        >
          Sí, eliminar
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
        Marca eliminada encontrada
      </h3>
      <p class="text-sm text-slate-500 mb-4">
        Ya existe una marca registrada con este nombre que fue eliminada anteriormente. ¿Deseas reactivarla?
      </p>
      
      <div class="bg-slate-50 p-4 rounded-2xl mb-6 text-xs space-y-2 border border-slate-100">
        <p class="text-slate-500 font-semibold uppercase tracking-wider text-[10px]">Datos de la marca guardada:</p>
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
          @click="reactivateBrand"
          class="px-4 py-2.5 bg-slate-900 hover:bg-slate-850 text-white rounded-xl text-sm font-semibold transition-all active:scale-[0.98]"
        >
          Sí, reactivar marca
        </button>
      </div>
    </div>
  </div>
</template>
