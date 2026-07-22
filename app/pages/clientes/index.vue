<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Edit2, Trash2, AlertCircle } from 'lucide-vue-next'

const supabase = useSupabaseClient()

const clientes = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

const editingClient = ref<any | null>(null)
const showDeleteConfirm = ref<number | null>(null)

const loadData = async () => {
  loading.value = true
  const { data, error } = await supabase
    .from('clientes')
    .select('*')
    .is('deleted_at', null)
    .order('id', { ascending: false })
  
  if (error) errorMsg.value = error.message
  clientes.value = data ?? []
  loading.value = false
}

onMounted(loadData)

const startEdit = (client: any) => {
  editingClient.value = client
}

const cancelEdit = () => {
  editingClient.value = null
}

const onSuccess = (payload?: any) => {
  if (payload && payload.reactivate) {
    editingClient.value = payload.item
  } else {
    editingClient.value = null
  }
  loadData()
}

const deleteRecord = async (id: number) => {
  errorMsg.value = ''
  const { error } = await supabase
    .from('clientes')
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
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Clientes</h1>

    <div class="bg-white p-5 rounded-lg shadow-sm mb-6">
      <ClientForm 
        :client="editingClient" 
        :show-cancel="!!editingClient" 
        @success="onSuccess" 
        @cancel="cancelEdit" 
      />
    </div>

    <p v-if="errorMsg" class="text-sm text-red-600 mb-4">{{ errorMsg }}</p>

    <div class="bg-white rounded-lg shadow-sm overflow-x-auto border border-slate-100">
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-left text-slate-600 border-b border-slate-100">
          <tr>
            <th class="px-5 py-3 font-semibold">Nombre o Razón Social</th>
            <th class="px-5 py-3 font-semibold">Teléfono</th>
            <th class="px-5 py-3 font-semibold">RIF</th>
            <th class="px-5 py-3 font-semibold">Domicilio Fiscal</th>
            <th class="px-5 py-3 font-semibold text-right">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td class="px-5 py-4 text-slate-500" colspan="5">Cargando clientes...</td>
          </tr>
          <tr v-else-if="clientes.length === 0">
            <td class="px-5 py-4 text-slate-500 text-center" colspan="5">No hay clientes registrados aún.</td>
          </tr>
          <tr v-for="cli in clientes" v-else :key="cli.id" class="border-b border-slate-100 hover:bg-slate-50 transition-colors">
            <td class="px-5 py-3 font-medium text-slate-800">{{ cli.nombre }}</td>
            <td class="px-5 py-3 text-slate-600">{{ cli.telefono || '—' }}</td>
            <td class="px-5 py-3 text-slate-600">{{ cli.rif || '—' }}</td>
            <td class="px-5 py-3 text-slate-600">{{ cli.ubicacion_geografica || '—' }}</td>
            <td class="px-5 py-3 text-right">
              <div class="flex items-center justify-end gap-1">
                <button 
                  @click="startEdit(cli)"
                  class="p-2 text-slate-400 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors"
                  title="Editar cliente"
                >
                  <Edit2 class="h-4 w-4" />
                </button>
                <button 
                  @click="showDeleteConfirm = cli.id"
                  class="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                  title="Eliminar cliente"
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
        ¿Eliminar cliente?
      </h3>
      <p class="text-sm text-slate-500 mb-6">
        Esta acción marcará al cliente como eliminado. Sus registros asociados en el histórico de movimientos se mantendrán intactos.
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
