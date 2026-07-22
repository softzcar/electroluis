<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Edit2, Trash2, AlertCircle } from 'lucide-vue-next'

const supabase = useSupabaseClient()

const licencias = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const editingLicense = ref<any | null>(null)
const showDeleteConfirm = ref<number | null>(null)

const loadData = async () => {
  loading.value = true
  const { data, error } = await supabase
    .from('licencias')
    .select('*')
    .is('deleted_at', null)
    .order('id', { ascending: false })
  
  if (error) errorMsg.value = error.message
  licencias.value = data ?? []
  loading.value = false
}

onMounted(loadData)

const startEdit = (license: any) => {
  editingLicense.value = license
}

const cancelEdit = () => {
  editingLicense.value = null
}

const onSuccess = () => {
  editingLicense.value = null
  loadData()
}

const deleteRecord = async (id: number) => {
  errorMsg.value = ''
  const { error } = await supabase
    .from('licencias')
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
  <div class="max-w-5xl mx-auto">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Licencias</h1>

    <div class="bg-white p-5 rounded-lg shadow-sm mb-6">
      <LicenseForm 
        :license="editingLicense" 
        :show-cancel="!!editingLicense" 
        @success="onSuccess" 
        @cancel="cancelEdit" 
      />
    </div>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow-sm overflow-x-auto border border-slate-100">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600 border-b border-slate-100">
          <tr>
            <th class="px-5 py-3 font-semibold">Nombre de la Licencia</th>
            <th class="px-5 py-3 font-semibold text-right">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-5 py-4 text-slate-500" colspan="2">Cargando licencias...</td>
          </tr>
          <tr v-else-if="licencias.length === 0">
            <td class="px-5 py-4 text-slate-500 text-center" colspan="2">No hay licencias registradas aún.</td>
          </tr>
          <tr v-for="lic in licencias" v-else :key="lic.id" class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
            <td class="px-5 py-3 font-medium text-slate-800">{{ lic.nombre }}</td>
            <td class="px-5 py-3 text-right">
              <div class="flex items-center justify-end gap-1">
                <button 
                  @click="startEdit(lic)"
                  class="p-2 text-slate-400 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors"
                  title="Editar licencia"
                >
                  <Edit2 class="h-4 w-4" />
                </button>
                <button 
                  @click="showDeleteConfirm = lic.id"
                  class="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                  title="Eliminar licencia"
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
        ¿Eliminar licencia?
      </h3>
      <p class="text-sm text-slate-500 mb-6">
        Esta acción marcará la licencia como eliminada. Sus registros históricos asociados en movimientos se mantendrán intactos.
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
</template>
