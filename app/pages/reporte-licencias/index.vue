<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useSupabaseClient } from '#imports'
import { 
  FileText, Search, ChevronDown, ChevronUp, X, Filter, 
  RefreshCw, Key, Users, Cpu, Printer, ClipboardList, AlertCircle
} from 'lucide-vue-next'

const supabase = useSupabaseClient()

// Fuentes de datos
const licencias = ref<any[]>([])
const installations = ref<any[]>([])
const loading = ref(false)
const listLoading = ref(false)
const errorMsg = ref('')

// Filtros y Autocompletado de Licencias
const licenseQuery = ref('')
const selectedLicense = ref<any | null>(null)
const showLicenseDropdown = ref(false)

// Búsqueda interna de resultados
const filterQuery = ref('')

const loadLicenses = async () => {
  loading.value = true
  const { data, error } = await supabase
    .from('licencias')
    .select('*')
    .is('deleted_at', null)
    .order('nombre')
  
  if (error) errorMsg.value = error.message
  licencias.value = data ?? []
  loading.value = false
}

const loadInstallations = async () => {
  if (!selectedLicense.value) {
    installations.value = []
    return
  }

  listLoading.value = true
  errorMsg.value = ''
  
  try {
    const { data, error } = await supabase
      .from('movimientos_licencias')
      .select(`
        id,
        key,
        created_at,
        movimientos(
          id,
          created_at,
          descripcion,
          clientes(
            id,
            nombre,
            telefono,
            rif,
            ubicacion_geografica
          ),
          movimientos_equipos(
            id,
            nro_serie,
            equipos(
              id,
              modelo,
              marcas(
                id,
                nombre
              )
            )
          )
        )
      `)
      .eq('id_licencia', selectedLicense.value.id)
      .order('created_at', { ascending: false })

    if (error) throw error
    installations.value = data ?? []
  } catch (err: any) {
    errorMsg.value = err.message || 'Error al obtener los datos de la licencia.'
  } finally {
    listLoading.value = false
  }
}

onMounted(loadLicenses)

// Volver a cargar si cambia la licencia seleccionada
watch(selectedLicense, () => {
  filterQuery.value = ''
  loadInstallations()
})

// Autocompletado de Licencias
const filteredLicenses = computed(() => {
  if (!licenseQuery.value) return licencias.value
  const q = licenseQuery.value.toLowerCase()
  return licencias.value.filter(l => l.nombre?.toLowerCase().includes(q))
})

const selectLicense = (lic: any) => {
  selectedLicense.value = lic
  licenseQuery.value = ''
  showLicenseDropdown.value = false
}

const clearLicense = () => {
  selectedLicense.value = null
  installations.value = []
}

// Filtrado de resultados local
const filteredInstallations = computed(() => {
  if (!filterQuery.value.trim()) return installations.value
  const q = filterQuery.value.trim().toLowerCase()

  return installations.value.filter(item => {
    const mov = item.movimientos
    const client = mov?.clientes
    const matchesClient = client?.nombre?.toLowerCase().includes(q) || 
                          client?.rif?.toLowerCase().includes(q) ||
                          client?.telefono?.toLowerCase().includes(q)
    
    const matchesKey = item.key?.toLowerCase().includes(q)
    
    const matchesEquip = mov?.movimientos_equipos?.some((me: any) => 
      me.equipos?.marcas?.nombre?.toLowerCase().includes(q) ||
      me.equipos?.modelo?.toLowerCase().includes(q) ||
      me.nro_serie?.toLowerCase().includes(q)
    )

    return matchesClient || matchesKey || matchesEquip
  })
})

// Estadísticas del reporte
const stats = computed(() => {
  const total = filteredInstallations.value.length
  
  const uniqueClients = new Set()
  const uniqueEquips = new Set()
  
  filteredInstallations.value.forEach(item => {
    const mov = item.movimientos
    if (mov?.clientes?.id) uniqueClients.add(mov.clientes.id)
    mov?.movimientos_equipos?.forEach((me: any) => {
      if (me.equipos?.id) uniqueEquips.add(me.equipos.id)
    })
  })

  return {
    total,
    clients: uniqueClients.size,
    equipments: uniqueEquips.size
  }
})

// Helpers para fechas e impresión
const formatDateStr = (dateStr?: string) => {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleDateString('es-ES', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric'
  })
}

const formatDateTime = (date: Date) => {
  return date.toLocaleString('es-ES', { 
    day: '2-digit', 
    month: '2-digit', 
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const imprimirReporte = () => {
  window.print()
}
</script>

<template>
  <div class="max-w-4xl mx-auto space-y-6 pb-12">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="p-2.5 bg-slate-900 text-white rounded-2xl shadow-sm">
          <FileText class="h-6 w-6" />
        </div>
        <div>
          <h1 class="text-2xl font-bold text-slate-800">Reporte de Licencias</h1>
          <p class="text-xs text-slate-500">Consulta en qué clientes y equipos se han instalado licencias y sus respectivas keys</p>
        </div>
      </div>
      
      <div class="flex gap-2" v-if="selectedLicense && installations.length > 0">
        <button 
          @click="imprimirReporte"
          class="p-2.5 bg-white border border-slate-200 text-slate-700 hover:bg-slate-50 rounded-2xl transition-colors shadow-sm flex items-center gap-2 text-sm font-semibold"
          title="Imprimir Reporte"
        >
          <Printer class="h-4 w-4" />
          <span class="hidden sm:inline">Imprimir</span>
        </button>
        <button 
          @click="loadInstallations"
          class="p-2.5 bg-white border border-slate-200 text-slate-700 hover:bg-slate-50 rounded-2xl transition-colors shadow-sm flex items-center gap-2 text-sm font-semibold"
          title="Refrescar datos"
        >
          <RefreshCw class="h-4 w-4" :class="{ 'animate-spin': listLoading }" />
          <span class="hidden sm:inline">Actualizar</span>
        </button>
      </div>
    </div>

    <!-- Selector de Licencia -->
    <div class="bg-white rounded-3xl p-6 shadow-sm border border-slate-100 space-y-4">
      <div class="relative max-w-md">
        <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Selecciona la Licencia para el Reporte</label>
        
        <div v-if="selectedLicense" class="flex items-center justify-between bg-slate-50 border border-slate-200 px-4 py-3 rounded-2xl text-sm font-semibold text-slate-800">
          <div class="flex items-center gap-2">
            <Key class="h-4 w-4 text-slate-500" />
            <span>{{ selectedLicense.nombre }}</span>
          </div>
          <button @click="clearLicense" class="text-slate-400 hover:text-red-500 transition-colors p-1">
            <X class="h-4 w-4" />
          </button>
        </div>
        
        <div v-else>
          <div class="relative">
            <Search class="absolute left-3.5 top-3.5 h-4 w-4 text-slate-450" />
            <input 
              v-model="licenseQuery"
              type="text"
              placeholder="Buscar licencia por nombre..."
              @focus="showLicenseDropdown = true"
              @blur="setTimeout(() => showLicenseDropdown = false, 200)"
              class="w-full pl-10 pr-4 py-3 border border-slate-200 rounded-2xl focus:ring-2 focus:ring-slate-950 focus:outline-none transition-shadow text-sm bg-slate-50 focus:bg-white"
            >
          </div>
          <!-- Dropdown -->
          <div v-if="showLicenseDropdown" class="absolute left-0 right-0 mt-2 bg-white rounded-2xl shadow-xl border border-slate-100 z-50 max-h-56 overflow-y-auto divide-y divide-slate-50">
            <div 
              v-for="l in filteredLicenses" 
              :key="l.id" 
              @mousedown="selectLicense(l)"
              class="px-4 py-3 hover:bg-slate-50 cursor-pointer text-sm font-medium text-slate-700 flex items-center gap-2 transition-colors"
            >
              <Key class="h-3.5 w-3.5 text-slate-400" />
              {{ l.nombre }}
            </div>
            <div v-if="filteredLicenses.length === 0" class="px-4 py-4 text-xs text-slate-400 text-center">
              Sin licencias encontradas
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Si no hay licencia seleccionada -->
    <div v-if="!selectedLicense" class="bg-white rounded-3xl p-12 text-center border border-slate-100 shadow-sm">
      <Key class="h-10 w-10 text-slate-300 mx-auto mb-3" />
      <p class="text-slate-800 font-bold mb-1">Sin licencia seleccionada</p>
      <p class="text-xs text-slate-500 max-w-sm mx-auto">Selecciona una licencia del menú superior para ver su historial de instalaciones, clientes y equipos asociados.</p>
    </div>

    <!-- Si hay licencia seleccionada -->
    <div v-else class="space-y-6">
      
      <!-- Stats Cards -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4" v-if="!listLoading && installations.length > 0">
        <div class="bg-white p-5 rounded-3xl border border-slate-100 shadow-sm flex items-center gap-4">
          <div class="p-3 bg-slate-950 text-white rounded-2xl shadow-sm">
            <Key class="h-5 w-5" />
          </div>
          <div>
            <span class="text-[10px] text-slate-450 font-bold uppercase tracking-wider block">Total Instaladas</span>
            <span class="text-xl font-black text-slate-800 font-mono">{{ stats.total }}</span>
          </div>
        </div>
        <div class="bg-white p-5 rounded-3xl border border-slate-100 shadow-sm flex items-center gap-4">
          <div class="p-3 bg-emerald-50 text-emerald-700 rounded-2xl shadow-sm">
            <Users class="h-5 w-5" />
          </div>
          <div>
            <span class="text-[10px] text-slate-450 font-bold uppercase tracking-wider block">Clientes Únicos</span>
            <span class="text-xl font-black text-slate-800 font-mono">{{ stats.clients }}</span>
          </div>
        </div>
        <div class="bg-white p-5 rounded-3xl border border-slate-100 shadow-sm flex items-center gap-4">
          <div class="p-3 bg-indigo-50 text-indigo-700 rounded-2xl shadow-sm">
            <Cpu class="h-5 w-5" />
          </div>
          <div>
            <span class="text-[10px] text-slate-450 font-bold uppercase tracking-wider block">Equipos Únicos</span>
            <span class="text-xl font-black text-slate-800 font-mono">{{ stats.equipments }}</span>
          </div>
        </div>
      </div>

      <!-- Buscador interno y resultados -->
      <div class="bg-white rounded-3xl border border-slate-100 shadow-sm overflow-hidden space-y-4 p-6" v-if="!listLoading">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2">
          <h2 class="text-base font-bold text-slate-800">
            Registros Encontrados
            <span class="text-xs text-slate-450 font-normal ml-1" v-if="installations.length > 0">
              (mostrando {{ filteredInstallations.length }} de {{ installations.length }})
            </span>
          </h2>
          <!-- Filtro de Búsqueda -->
          <div class="relative w-full sm:w-72" v-if="installations.length > 0">
            <Search class="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
            <input 
              v-model="filterQuery"
              type="text"
              placeholder="Filtrar por cliente, key o serial..."
              class="w-full pl-9 pr-4 py-1.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-xs"
            >
          </div>
        </div>

        <!-- Spinner de Carga -->
        <div v-if="listLoading" class="py-12 text-center">
          <RefreshCw class="h-8 w-8 animate-spin mx-auto text-slate-450 mb-3" />
          <p class="text-sm text-slate-500 font-medium">Buscando datos de la licencia...</p>
        </div>

        <!-- Mensaje de Error -->
        <div v-else-if="errorMsg" class="bg-red-50 border border-red-100 text-red-700 rounded-2xl p-4 text-sm">
          {{ errorMsg }}
        </div>

        <!-- Sin registros -->
        <div v-else-if="installations.length === 0" class="text-center py-12 border border-dashed border-slate-200 rounded-2xl">
          <AlertCircle class="h-8 w-8 text-slate-300 mx-auto mb-2" />
          <p class="text-sm text-slate-800 font-bold">Sin instalaciones</p>
          <p class="text-xs text-slate-400 max-w-xs mx-auto mt-0.5">Esta licencia no se ha registrado en ningún movimiento técnico todavía.</p>
        </div>

        <!-- Tabla de Resultados -->
        <div v-else class="overflow-x-auto">
          <table class="w-full text-left text-sm border-collapse">
            <thead class="bg-slate-50 text-slate-600 font-semibold border-b border-slate-100">
              <tr>
                <th class="px-4 py-3 text-xs uppercase tracking-wider font-bold">Cliente</th>
                <th class="px-4 py-3 text-xs uppercase tracking-wider font-bold">Equipos Asignados</th>
                <th class="px-4 py-3 text-xs uppercase tracking-wider font-bold">Clave / Key</th>
                <th class="px-4 py-3 text-xs uppercase tracking-wider font-bold">Fecha Inst.</th>
                <th class="px-4 py-3 text-xs uppercase tracking-wider font-bold">Detalles / Trabajo</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr v-for="item in filteredInstallations" :key="item.id" class="hover:bg-slate-50/50 transition-colors">
                <!-- Cliente -->
                <td class="px-4 py-3.5 max-w-[200px]">
                  <p class="font-bold text-slate-800 text-xs truncate" :title="item.movimientos?.clientes?.nombre">
                    {{ item.movimientos?.clientes?.nombre || '—' }}
                  </p>
                  <p class="text-[10px] text-slate-500 font-mono mt-0.5" v-if="item.movimientos?.clientes?.rif">
                    RIF: {{ item.movimientos.clientes.rif }}
                  </p>
                  <p class="text-[10px] text-slate-400 mt-0.5 truncate" v-if="item.movimientos?.clientes?.telefono">
                    Tel: {{ item.movimientos.clientes.telefono }}
                  </p>
                </td>
                
                <!-- Equipos -->
                <td class="px-4 py-3.5 max-w-[220px] space-y-1">
                  <div 
                    v-for="me in item.movimientos?.movimientos_equipos" 
                    :key="me.id"
                    class="leading-snug"
                  >
                    <p class="text-[11px] font-bold text-slate-800">
                      {{ me.equipos?.marcas?.nombre }} {{ me.equipos?.modelo }}
                    </p>
                    <p class="text-[10px] text-slate-500 font-mono">
                      S/N: {{ me.nro_serie || '—' }}
                    </p>
                  </div>
                  <span v-if="!item.movimientos?.movimientos_equipos || item.movimientos.movimientos_equipos.length === 0" class="text-xs text-slate-400">—</span>
                </td>

                <!-- Key -->
                <td class="px-4 py-3.5">
                  <span class="text-xs font-bold text-slate-800 font-mono bg-slate-100 px-2 py-1 rounded-md border border-slate-200 break-all select-all">
                    {{ item.key }}
                  </span>
                </td>

                <!-- Fecha -->
                <td class="px-4 py-3.5 text-xs text-slate-650 font-mono">
                  {{ formatDateStr(item.created_at) }}
                </td>

                <!-- Detalles / Trabajo -->
                <td class="px-4 py-3.5 max-w-[220px]">
                  <p class="text-[11px] text-slate-600 leading-normal line-clamp-2" :title="item.movimientos?.descripcion">
                    {{ item.movimientos?.descripcion || '—' }}
                  </p>
                  <span class="text-[9px] bg-slate-900 text-white font-mono px-1.5 py-0.5 rounded-md mt-1 inline-block">
                    Mov #{{ item.movimientos?.id }}
                  </span>
                </td>
              </tr>
              <tr v-if="filteredInstallations.length === 0">
                <td colspan="5" class="px-4 py-6 text-center text-xs text-slate-405 italic">
                  Ningún registro coincide con el filtro de búsqueda.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

      </div>
    </div>

    <!-- Reporte Imprimible (Oculto en pantalla, se muestra en print) -->
    <div v-if="selectedLicense" class="print-report hidden print:block bg-white text-black p-4 md:p-8 font-sans w-full">
      <!-- Header del reporte -->
      <div class="flex justify-between items-start border-b-2 border-slate-900 pb-4 mb-6">
        <div>
          <h1 class="text-xl font-black uppercase tracking-tighter leading-none mb-2">Reporte de Instalaciones de Licencia</h1>
          <div class="flex flex-wrap gap-4 text-[9px] font-bold text-slate-600">
             <p>LICENCIA: <span class="text-black font-black uppercase">{{ selectedLicense.nombre }}</span></p>
             <p>EMITIDO: {{ formatDateTime(new Date()) }}</p>
             <p v-if="filterQuery">FILTRO APLICADO: "{{ filterQuery }}"</p>
          </div>
        </div>
        <div class="text-right">
           <p class="text-base font-black leading-none">Medic Play</p>
           <p class="text-[9px] uppercase font-bold text-slate-500">Histórico de Taller</p>
        </div>
      </div>

      <!-- Tabla de Impresión -->
      <table class="w-full border-collapse border border-slate-300">
        <thead>
          <tr class="bg-slate-100 border-b border-slate-300 text-[8px] font-black uppercase">
            <th class="p-1.5 text-center w-12 border-r border-slate-300">Mov #</th>
            <th class="p-1.5 text-left w-36 border-r border-slate-300">Cliente</th>
            <th class="p-1.5 text-left border-r border-slate-300">Equipos & Seriales</th>
            <th class="p-1.5 text-left border-r border-slate-300">Clave / Key</th>
            <th class="p-1.5 text-left border-r border-slate-300">Fecha Inst.</th>
            <th class="p-1.5 text-left">Trabajo Realizado</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in filteredInstallations" :key="item.id" class="border-b border-slate-200 page-break-inside-avoid">
            <td class="p-1.5 text-center text-[10px] font-bold border-r border-slate-200">{{ item.movimientos?.id }}</td>
            <td class="p-1.5 text-[9px] border-r border-slate-200">
              <p class="font-bold text-slate-900">{{ item.movimientos?.clientes?.nombre }}</p>
              <p class="text-[8px] text-slate-500 font-mono" v-if="item.movimientos?.clientes?.rif">RIF: {{ item.movimientos.clientes.rif }}</p>
              <p class="text-[8px] text-slate-400 font-mono" v-if="item.movimientos?.clientes?.telefono">Tel: {{ item.movimientos.clientes.telefono }}</p>
            </td>
            <td class="p-1.5 text-[8px] border-r border-slate-200 space-y-1">
              <div v-for="me in item.movimientos?.movimientos_equipos" :key="me.id" class="leading-tight">
                <span class="font-bold text-slate-800">{{ me.equipos?.marcas?.nombre }} {{ me.equipos?.modelo }}</span>
                <span class="text-slate-500 block">S/N: <span class="font-mono">{{ me.nro_serie || '—' }}</span></span>
              </div>
            </td>
            <td class="p-1.5 text-[9px] font-mono font-bold border-r border-slate-200 break-all">
              {{ item.key }}
            </td>
            <td class="p-1.5 text-[9px] font-mono border-r border-slate-200">
              {{ formatDateStr(item.created_at) }}
            </td>
            <td class="p-1.5 text-[9px] text-slate-700 leading-normal">{{ item.movimientos?.descripcion || '—' }}</td>
          </tr>
        </tbody>
      </table>

      <!-- Pie de página -->
      <div class="mt-8 pt-6 border-t border-slate-200 flex justify-between items-end text-[8px] font-bold text-slate-400">
         <div>
            <p>ESTE DOCUMENTO ES UN REGISTRO HISTÓRICO DE CONTROL INTERNO DE LICENCIAS - MEDIC PLAY.</p>
         </div>
         <div class="text-right">
            Página ____ de ____
         </div>
       </div>
    </div>

  </div>
</template>

<style scoped>
@media print {
  table {
    page-break-inside: auto;
  }
  tr {
    page-break-inside: avoid;
    page-break-after: auto;
  }
  thead {
    display: table-header-group;
  }
  @page {
    size: letter;
    margin: 1cm;
  }
  * {
    color: black !important;
    background: transparent !important;
    box-shadow: none !important;
    text-shadow: none !important;
  }
  body, .max-w-4xl {
    max-width: 100% !important;
    width: 100% !important;
    margin: 0 !important;
    padding: 0 !important;
  }
  nav, header, aside, button, .bg-white, .shadow-sm, .rounded-3xl, .relative {
    display: none !important;
  }
  .print-report {
    display: block !important;
  }
}
</style>
