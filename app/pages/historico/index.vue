<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useSupabaseClient } from '#imports'
import { useBarcodeScanner } from '~/composables/useBarcodeScanner'
import { 
  History, Users, Cpu, Wrench, Search, ChevronDown, ChevronUp, 
  X, Filter, Calendar, Barcode, Hash, RefreshCw, Phone, Printer, Key
} from 'lucide-vue-next'

const supabase = useSupabaseClient()

// Fuentes de datos básicas para autocompletados
const clientes = ref<any[]>([])
const marcas = ref<any[]>([])
const equipos = ref<any[]>([])
const movimientos = ref<any[]>([])

const loading = ref(false)
const errorMsg = ref('')
const showFilters = ref(true) // visible por defecto en escritorio, colapsable

// Rango de fechas por defecto: últimos 30 días
const getPastDateString = (daysAgo: number) => {
  const d = new Date()
  d.setDate(d.getDate() - daysAgo)
  return d.toISOString().split('T')[0]
}

const getTodayString = () => {
  return new Date().toISOString().split('T')[0]
}

const dateFrom = ref(getPastDateString(30))
const dateTo = ref(getTodayString())

// Filtros reactivos
const reportIdQuery = ref('')
const repuestoQuery = ref('')
const serialQuery = ref('')

// Estados de Autocompletados (queries y selecciones)
const clientQuery = ref('')
const selectedClient = ref<any | null>(null)
const showClientDropdown = ref(false)

const brandQuery = ref('')
const selectedBrand = ref<any | null>(null)
const showBrandDropdown = ref(false)

const modelQuery = ref('')
const selectedModel = ref<string | null>(null)
const showModelDropdown = ref(false)

const equipmentQuery = ref('')
const selectedEquipment = ref<any | null>(null)
const showEquipmentDropdown = ref(false)

// Estado de expansión de filas/tarjetas de movimientos
const expandedMovimientos = ref<Record<number, boolean>>({})

// Cargar catálogos iniciales
const loadCatalogs = async () => {
  const [
    { data: cl },
    { data: br },
    { data: eq }
  ] = await Promise.all([
    supabase.from('clientes').select('*').is('deleted_at', null).order('nombre'),
    supabase.from('marcas').select('*').is('deleted_at', null).order('nombre'),
    supabase.from('equipos').select('*, marcas(nombre)').is('deleted_at', null).order('modelo')
  ])
  clientes.value = cl ?? []
  marcas.value = br ?? []
  equipos.value = eq ?? []
}

// Cargar movimientos desde Supabase filtrados únicamente por rango de fecha
const loadMovimientos = async () => {
  loading.value = true
  errorMsg.value = ''
  
  try {
    const { data, error } = await supabase
      .from('movimientos')
      .select(`
        id,
        descripcion,
        created_at,
        id_cliente,
        clientes(id, nombre, telefono, ubicacion_geografica, rif),
        movimientos_equipos(
          id,
          nro_serie,
          id_equipo,
          equipos(
            id,
            modelo,
            id_marca,
            marcas(id, nombre)
          )
        ),
        movimientos_productos(
          id,
          cantidad,
          id_repuesto,
          repuestos(
            id,
            nombre,
            codigo_barras
          )
        ),
        movimientos_licencias(
          id,
          key,
          id_licencia,
          licencias(
            id,
            nombre
          )
        )
      `)
      .gte('created_at', `${dateFrom.value}T00:00:00Z`)
      .lte('created_at', `${dateTo.value}T23:59:59Z`)
      .order('id', { ascending: false })

    if (error) throw error
    movimientos.value = data ?? []
  } catch (err: any) {
    errorMsg.value = err.message || 'Error al obtener los movimientos.'
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await Promise.all([
    loadCatalogs(),
    loadMovimientos()
  ])
})

// Volver a cargar si cambian las fechas
watch([dateFrom, dateTo], () => {
  loadMovimientos()
})

// Escáner de código de barras
useBarcodeScanner((code) => {
  repuestoQuery.value = code
})

// --- LÓGICA DE AUTOCOMPLETADOS ---

// Clientes
const filteredClientes = computed(() => {
  if (!clientQuery.value) return []
  const q = clientQuery.value.toLowerCase()
  return clientes.value.filter(c => 
    c.nombre?.toLowerCase().includes(q) || 
    c.telefono?.toLowerCase().includes(q) ||
    c.rif?.toLowerCase().includes(q)
  )
})

const selectClient = (client: any) => {
  selectedClient.value = client
  clientQuery.value = ''
  showClientDropdown.value = false
}

// Marcas
const filteredBrands = computed(() => {
  if (!brandQuery.value) return marcas.value
  const q = brandQuery.value.toLowerCase()
  return marcas.value.filter(m => m.nombre?.toLowerCase().includes(q))
})

const selectBrand = (brand: any) => {
  selectedBrand.value = brand
  brandQuery.value = ''
  showBrandDropdown.value = false
  
  // Limpiar modelo y equipo completo si ya no corresponden a la nueva marca
  if (selectedModel.value) {
    const modelStillValid = equipos.value.some(e => e.id_marca === brand.id && e.modelo === selectedModel.value)
    if (!modelStillValid) selectedModel.value = null
  }
  if (selectedEquipment.value && selectedEquipment.value.id_marca !== brand.id) {
    selectedEquipment.value = null
  }
}

// Modelos (obtenidos dinámicamente de equipos y filtrados por marca)
const availableModels = computed(() => {
  let list = equipos.value
  if (selectedBrand.value) {
    list = list.filter(e => e.id_marca === selectedBrand.value.id)
  }
  const uniqueModels = Array.from(new Set(list.map(e => e.modelo))).filter(Boolean) as string[]
  return uniqueModels.sort((a, b) => a.localeCompare(b))
})

const filteredModels = computed(() => {
  if (!modelQuery.value) return availableModels.value
  const q = modelQuery.value.toLowerCase()
  return availableModels.value.filter(m => m.toLowerCase().includes(q))
})

const selectModel = (model: string) => {
  selectedModel.value = model
  modelQuery.value = ''
  showModelDropdown.value = false

  // Si no hay marca seleccionada, autodetectar y seleccionar la marca de este modelo
  if (!selectedBrand.value) {
    const eqWithModel = equipos.value.find(e => e.modelo === model)
    if (eqWithModel) {
      selectedBrand.value = marcas.value.find(m => m.id === eqWithModel.id_marca) || null
    }
  }

  // Limpiar equipo seleccionado si no corresponde al modelo
  if (selectedEquipment.value && selectedEquipment.value.modelo !== model) {
    selectedEquipment.value = null
  }
}

// Equipos Completos (filtrados por marca y modelo seleccionados)
const availableEquipments = computed(() => {
  let list = equipos.value
  if (selectedBrand.value) {
    list = list.filter(e => e.id_marca === selectedBrand.value.id)
  }
  if (selectedModel.value) {
    list = list.filter(e => e.modelo === selectedModel.value)
  }
  return list
})

const filteredEquipments = computed(() => {
  if (!equipmentQuery.value) return availableEquipments.value
  const q = equipmentQuery.value.toLowerCase()
  return availableEquipments.value.filter(e => 
    e.marcas?.nombre?.toLowerCase().includes(q) || 
    e.modelo?.toLowerCase().includes(q)
  )
})

const selectEquipment = (eq: any) => {
  selectedEquipment.value = eq
  equipmentQuery.value = ''
  showEquipmentDropdown.value = false

  // Inteligente: Sincronizar marca y modelo correspondientes
  selectedBrand.value = marcas.value.find(m => m.id === eq.id_marca) || null
  selectedModel.value = eq.modelo
}

// Limpiar filtros específicos
const clearClient = () => { selectedClient.value = null }
const clearBrand = () => { 
  selectedBrand.value = null 
  selectedModel.value = null
  selectedEquipment.value = null
}
const clearModel = () => { 
  selectedModel.value = null 
  selectedEquipment.value = null
}
const clearEquipment = () => { selectedEquipment.value = null }

const clearAllFilters = () => {
  reportIdQuery.value = ''
  repuestoQuery.value = ''
  serialQuery.value = ''
  selectedClient.value = null
  selectedBrand.value = null
  selectedModel.value = null
  selectedEquipment.value = null
  dateFrom.value = getPastDateString(30)
  dateTo.value = getTodayString()
}

// --- FILTRADO CLIENT-SIDE INTELIGENTE ---
const filteredMovimientos = computed(() => {
  return movimientos.value.filter(mov => {
    // 1. ID del reporte
    if (reportIdQuery.value.trim()) {
      if (!mov.id.toString().includes(reportIdQuery.value.trim())) return false
    }

    // 2. Cliente
    if (selectedClient.value) {
      if (mov.id_cliente !== selectedClient.value.id) return false
    }

    // 3. Repuesto (nombre o código de barra)
    if (repuestoQuery.value.trim()) {
      const q = repuestoQuery.value.trim().toLowerCase()
      const matchesRep = mov.movimientos_productos?.some((mp: any) => 
        mp.repuestos?.nombre?.toLowerCase().includes(q) ||
        mp.repuestos?.codigo_barras?.toLowerCase() === q
      )
      if (!matchesRep) return false
    }

    // 4. Número de serie
    if (serialQuery.value.trim()) {
      const q = serialQuery.value.trim().toLowerCase()
      const matchesSerial = mov.movimientos_equipos?.some((me: any) => 
        me.nro_serie?.toLowerCase().includes(q)
      )
      if (!matchesSerial) return false
    }

    // 5. Equipo completo
    if (selectedEquipment.value) {
      const matchesEq = mov.movimientos_equipos?.some((me: any) => 
        me.id_equipo === selectedEquipment.value.id
      )
      if (!matchesEq) return false
    } else {
      // 5a. Filtrar por Marca
      if (selectedBrand.value) {
        const matchesBr = mov.movimientos_equipos?.some((me: any) => 
          me.equipos?.id_marca === selectedBrand.value.id
        )
        if (!matchesBr) return false
      }

      // 5b. Filtrar por Modelo
      if (selectedModel.value) {
        const matchesMo = mov.movimientos_equipos?.some((me: any) => 
          me.equipos?.modelo?.toLowerCase() === selectedModel.value.toLowerCase()
        )
        if (!matchesMo) return false
      }
    }

    return true
  })
})

const activeFiltersCount = computed(() => {
  let count = 0
  if (reportIdQuery.value) count++
  if (selectedClient.value) count++
  if (repuestoQuery.value) count++
  if (serialQuery.value) count++
  if (selectedBrand.value) count++
  if (selectedModel.value) count++
  if (selectedEquipment.value) count++
  return count
})

const toggleExpand = (id: number) => {
  expandedMovimientos.value[id] = !expandedMovimientos.value[id]
}

// --- ORDENACIÓN ---
const sortBy = ref('id')
const sortOrder = ref<'asc' | 'desc'>('desc')

const setSort = (field: string) => {
  if (sortBy.value === field) {
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortBy.value = field
    sortOrder.value = 'asc'
  }
}

const sortedMovimientos = computed(() => {
  const list = [...filteredMovimientos.value]
  return list.sort((a, b) => {
    if (sortBy.value === 'id') {
      return sortOrder.value === 'asc' ? a.id - b.id : b.id - a.id
    } else if (sortBy.value === 'fecha') {
      const dateA = new Date(a.created_at).getTime()
      const dateB = new Date(b.created_at).getTime()
      return sortOrder.value === 'asc' ? dateA - dateB : dateB - dateA
    } else if (sortBy.value === 'cliente') {
      const nameA = a.clientes?.nombre || ''
      const nameB = b.clientes?.nombre || ''
      return sortOrder.value === 'asc' 
        ? nameA.localeCompare(nameB) 
        : nameB.localeCompare(nameA)
    }
    return 0
  })
})

// --- IMPRESIÓN ---
const formatDateStr = (dateStr?: string) => {
  if (!dateStr) return 'N/A'
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

const activeFiltersSummary = computed(() => {
  const parts = []
  parts.push(`Periodo: ${formatDateStr(dateFrom.value)} al ${formatDateStr(dateTo.value)}`)
  if (reportIdQuery.value.trim()) parts.push(`ID: "${reportIdQuery.value.trim()}"`)
  if (selectedClient.value) parts.push(`Cliente: "${selectedClient.value.nombre}"`)
  if (repuestoQuery.value.trim()) parts.push(`Repuesto: "${repuestoQuery.value.trim()}"`)
  if (selectedBrand.value) parts.push(`Marca: "${selectedBrand.value.nombre}"`)
  if (selectedModel.value) parts.push(`Modelo: "${selectedModel.value}"`)
  if (selectedEquipment.value) parts.push(`Equipo: "${selectedEquipment.value.marcas?.nombre} ${selectedEquipment.value.modelo}"`)
  if (serialQuery.value.trim()) parts.push(`Serial: "${serialQuery.value.trim()}"`)
  return parts.join(' | ')
})

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
          <History class="h-6 w-6" />
        </div>
        <div>
          <h1 class="text-2xl font-bold text-slate-800">Histórico</h1>
          <p class="text-xs text-slate-500">Consulta y busca registros pasados de movimientos</p>
        </div>
      </div>
      
      <div class="flex gap-2">
        <button 
          @click="imprimirReporte"
          class="p-2.5 bg-white border border-slate-200 text-slate-700 hover:bg-slate-50 rounded-2xl transition-colors shadow-sm flex items-center gap-2 text-sm font-semibold"
          title="Imprimir Reporte"
        >
          <Printer class="h-4 w-4" />
          <span class="hidden sm:inline">Imprimir</span>
        </button>
        <button 
          @click="loadMovimientos"
          class="p-2.5 bg-white border border-slate-200 text-slate-700 hover:bg-slate-50 rounded-2xl transition-colors shadow-sm flex items-center gap-2 text-sm font-semibold"
          title="Refrescar datos"
        >
          <RefreshCw class="h-4 w-4" :class="{ 'animate-spin': loading }" />
          <span class="hidden sm:inline">Actualizar</span>
        </button>
      </div>
    </div>

    <!-- Panel de Filtros -->
    <div class="bg-white rounded-3xl shadow-sm border border-slate-100 overflow-hidden">
      <!-- Filtros Header -->
      <div 
        @click="showFilters = !showFilters"
        class="px-6 py-4 flex items-center justify-between border-b border-slate-50 cursor-pointer select-none bg-slate-50/50 hover:bg-slate-50 transition-colors"
      >
        <div class="flex items-center gap-2">
          <Filter class="h-5 w-5 text-slate-600" />
          <span class="font-bold text-slate-800">Filtros de Búsqueda</span>
          <span 
            v-if="activeFiltersCount > 0"
            class="ml-2 bg-slate-950 text-white text-[10px] font-extrabold px-2 py-0.5 rounded-full"
          >
            {{ activeFiltersCount }} activos
          </span>
        </div>
        <div class="text-slate-400">
          <ChevronUp v-if="showFilters" class="h-5 w-5" />
          <ChevronDown v-else class="h-5 w-5" />
        </div>
      </div>

      <!-- Filtros Contenido -->
      <div v-show="showFilters" class="p-6 space-y-6 animate-in fade-in duration-200">
        <!-- Grid de Filtros -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          
          <!-- Rango de Fechas -->
          <div class="space-y-2 md:col-span-2">
            <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
              <Calendar class="h-3.5 w-3.5" /> Rango de Fechas
            </label>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <span class="text-[10px] text-slate-400 font-semibold block mb-0.5">Desde</span>
                <input 
                  v-model="dateFrom" 
                  type="date"
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
                >
              </div>
              <div>
                <span class="text-[10px] text-slate-400 font-semibold block mb-0.5">Hasta</span>
                <input 
                  v-model="dateTo" 
                  type="date"
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
                >
              </div>
            </div>
          </div>

          <!-- ID del reporte -->
          <div class="space-y-2">
            <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
              <Hash class="h-3.5 w-3.5" /> ID del Reporte
            </label>
            <input 
              v-model="reportIdQuery"
              type="text"
              placeholder="Ej. 143"
              class="w-full px-3.5 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
            >
          </div>

          <!-- Cliente (Typeahead) -->
          <div class="space-y-2 relative">
            <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
              <Users class="h-3.5 w-3.5" /> Cliente
            </label>
            <div v-if="selectedClient" class="flex items-center justify-between bg-slate-50 border border-slate-200 px-3.5 py-2 rounded-xl text-sm font-medium">
              <span class="truncate text-slate-800">{{ selectedClient.nombre }}</span>
              <button @click="clearClient" class="text-slate-400 hover:text-red-500 transition-colors p-0.5">
                <X class="h-4 w-4" />
              </button>
            </div>
            <div v-else>
              <input 
                v-model="clientQuery"
                type="text"
                placeholder="Buscar por nombre o cel..."
                @focus="showClientDropdown = true"
                class="w-full px-3.5 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
              >
              <!-- Dropdown -->
              <div v-if="showClientDropdown && clientQuery" class="absolute left-0 right-0 mt-1 bg-white rounded-xl shadow-xl border border-slate-100 z-50 max-h-48 overflow-y-auto">
                <div 
                  v-for="c in filteredClientes" 
                  :key="c.id" 
                  @click="selectClient(c)"
                  class="px-4 py-2 hover:bg-slate-50 cursor-pointer text-sm border-b border-slate-50 last:border-0 truncate"
                >
                  <p class="font-bold text-slate-800">{{ c.nombre }}</p>
                  <p class="text-[10px] text-slate-500 font-semibold" v-if="c.rif">RIF: {{ c.rif }}</p>
                  <p class="text-[10px] text-slate-400 font-mono">{{ c.telefono || 'Sin teléfono' }}</p>
                </div>
                <div v-if="filteredClientes.length === 0" class="px-4 py-3 text-xs text-slate-400 text-center">
                  Sin coincidencias
                </div>
              </div>
            </div>
          </div>

          <!-- Repuesto (barCode / nombre) -->
          <div class="space-y-2">
            <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
              <Barcode class="h-3.5 w-3.5" /> Repuesto (Nombre/Código)
            </label>
            <div class="relative">
              <input 
                v-model="repuestoQuery"
                type="text"
                placeholder="Nombre o escanea barras..."
                class="w-full pl-3 pr-9 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm font-sans"
              >
              <Barcode class="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
            </div>
          </div>

          <!-- Equipo Marca (Typeahead) -->
          <div class="space-y-2 relative">
            <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
              <Cpu class="h-3.5 w-3.5" /> Marca de Equipo
            </label>
            <div v-if="selectedBrand" class="flex items-center justify-between bg-slate-50 border border-slate-200 px-3.5 py-2 rounded-xl text-sm font-medium">
              <span class="truncate text-slate-800">{{ selectedBrand.nombre }}</span>
              <button @click="clearBrand" class="text-slate-400 hover:text-red-500 transition-colors p-0.5">
                <X class="h-4 w-4" />
              </button>
            </div>
            <div v-else>
              <input 
                v-model="brandQuery"
                type="text"
                placeholder="Buscar marca..."
                @focus="showBrandDropdown = true"
                class="w-full px-3.5 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
              >
              <!-- Dropdown -->
              <div v-if="showBrandDropdown" class="absolute left-0 right-0 mt-1 bg-white rounded-xl shadow-xl border border-slate-100 z-50 max-h-48 overflow-y-auto">
                <div 
                  v-for="b in filteredBrands" 
                  :key="b.id" 
                  @click="selectBrand(b)"
                  class="px-4 py-2 hover:bg-slate-50 cursor-pointer text-sm border-b border-slate-50 last:border-0 truncate font-semibold"
                >
                  {{ b.nombre }}
                </div>
              </div>
            </div>
          </div>

          <!-- Equipo Modelo (Typeahead) -->
          <div class="space-y-2 relative">
            <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
              <Cpu class="h-3.5 w-3.5" /> Modelo de Equipo
            </label>
            <div v-if="selectedModel" class="flex items-center justify-between bg-slate-50 border border-slate-200 px-3.5 py-2 rounded-xl text-sm font-medium">
              <span class="truncate text-slate-800">{{ selectedModel }}</span>
              <button @click="clearModel" class="text-slate-400 hover:text-red-500 transition-colors p-0.5">
                <X class="h-4 w-4" />
              </button>
            </div>
            <div v-else>
              <input 
                v-model="modelQuery"
                type="text"
                placeholder="Buscar modelo..."
                @focus="showModelDropdown = true"
                class="w-full px-3.5 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
              >
              <!-- Dropdown -->
              <div v-if="showModelDropdown" class="absolute left-0 right-0 mt-1 bg-white rounded-xl shadow-xl border border-slate-100 z-50 max-h-48 overflow-y-auto">
                <div 
                  v-for="m in filteredModels" 
                  :key="m" 
                  @click="selectModel(m)"
                  class="px-4 py-2 hover:bg-slate-50 cursor-pointer text-sm border-b border-slate-50 last:border-0 truncate"
                >
                  {{ m }}
                </div>
                <div v-if="filteredModels.length === 0" class="px-4 py-3 text-xs text-slate-400 text-center">
                  Sin modelos disponibles
                </div>
              </div>
            </div>
          </div>

          <!-- Equipo Completo (Typeahead) -->
          <div class="space-y-2 relative">
            <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
              <Cpu class="h-3.5 w-3.5" /> Equipo del Catálogo
            </label>
            <div v-if="selectedEquipment" class="flex items-center justify-between bg-slate-50 border border-slate-200 px-3.5 py-2 rounded-xl text-sm font-medium">
              <span class="truncate text-slate-800">{{ selectedEquipment.marcas?.nombre }} {{ selectedEquipment.modelo }}</span>
              <button @click="clearEquipment" class="text-slate-400 hover:text-red-500 transition-colors p-0.5">
                <X class="h-4 w-4" />
              </button>
            </div>
            <div v-else>
              <input 
                v-model="equipmentQuery"
                type="text"
                placeholder="Marca o modelo completo..."
                @focus="showEquipmentDropdown = true"
                class="w-full px-3.5 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
              >
              <!-- Dropdown -->
              <div v-if="showEquipmentDropdown && equipmentQuery" class="absolute left-0 right-0 mt-1 bg-white rounded-xl shadow-xl border border-slate-100 z-50 max-h-48 overflow-y-auto">
                <div 
                  v-for="e in filteredEquipments" 
                  :key="e.id" 
                  @click="selectEquipment(e)"
                  class="px-4 py-2 hover:bg-slate-50 cursor-pointer text-sm border-b border-slate-50 last:border-0 truncate"
                >
                  <p class="font-bold text-slate-800">{{ e.marcas?.nombre }}</p>
                  <p class="text-xs text-slate-500">Modelo: {{ e.modelo }}</p>
                </div>
                <div v-if="filteredEquipments.length === 0" class="px-4 py-3 text-xs text-slate-400 text-center">
                  Sin equipos disponibles
                </div>
              </div>
            </div>
          </div>

          <!-- Serial del equipo -->
          <div class="space-y-2">
            <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
              <Hash class="h-3.5 w-3.5" /> Serial del Equipo
            </label>
            <input 
              v-model="serialQuery"
              type="text"
              placeholder="Ej. SN123456"
              class="w-full px-3.5 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm font-mono"
            >
          </div>

        </div>

        <!-- Botón Limpiar -->
        <div class="flex justify-end pt-2 border-t border-slate-100">
          <button 
            @click="clearAllFilters"
            class="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-semibold rounded-xl transition-colors text-xs flex items-center gap-1.5"
          >
            Limpiar Filtros
          </button>
        </div>
      </div>
    </div>

    <!-- Lista de Movimientos -->
    <div class="space-y-4">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 px-2">
        <h2 class="text-lg font-bold text-slate-800">
          Resultados 
          <span class="text-xs text-slate-400 font-normal ml-1">
            (mostrando {{ sortedMovimientos.length }} de {{ movimientos.length }} en fecha)
          </span>
        </h2>
        <div class="flex items-center gap-2 text-xs">
          <span class="text-slate-400 font-semibold">Ordenar por:</span>
          <button 
            @click="setSort('id')"
            class="px-2.5 py-1.5 rounded-lg border font-semibold transition-colors"
            :class="sortBy === 'id' ? 'bg-slate-900 border-slate-900 text-white' : 'bg-white border-slate-200 text-slate-700 hover:bg-slate-50'"
          >
            ID {{ sortBy === 'id' ? (sortOrder === 'asc' ? '▲' : '▼') : '' }}
          </button>
          <button 
            @click="setSort('fecha')"
            class="px-2.5 py-1.5 rounded-lg border font-semibold transition-colors"
            :class="sortBy === 'fecha' ? 'bg-slate-900 border-slate-900 text-white' : 'bg-white border-slate-200 text-slate-700 hover:bg-slate-50'"
          >
            Fecha {{ sortBy === 'fecha' ? (sortOrder === 'asc' ? '▲' : '▼') : '' }}
          </button>
          <button 
            @click="setSort('cliente')"
            class="px-2.5 py-1.5 rounded-lg border font-semibold transition-colors"
            :class="sortBy === 'cliente' ? 'bg-slate-900 border-slate-900 text-white' : 'bg-white border-slate-200 text-slate-700 hover:bg-slate-50'"
          >
            Cliente {{ sortBy === 'cliente' ? (sortOrder === 'asc' ? '▲' : '▼') : '' }}
          </button>
        </div>
      </div>

      <!-- Spinner de Carga -->
      <div v-if="loading" class="bg-white rounded-3xl p-12 text-center border border-slate-100">
        <RefreshCw class="h-8 w-8 animate-spin mx-auto text-slate-400 mb-3" />
        <p class="text-sm text-slate-500 font-medium">Obteniendo registros de movimientos...</p>
      </div>

      <!-- Mensaje de Error -->
      <div v-else-if="errorMsg" class="bg-red-50 border border-red-100 rounded-3xl p-6 text-red-700 text-sm">
        {{ errorMsg }}
      </div>

      <!-- Sin Resultados -->
      <div v-else-if="sortedMovimientos.length === 0" class="bg-white rounded-3xl p-12 text-center border border-slate-100 shadow-sm">
        <History class="h-10 w-10 text-slate-300 mx-auto mb-3" />
        <p class="text-slate-800 font-bold mb-1">Sin registros</p>
        <p class="text-xs text-slate-500 max-w-sm mx-auto">No se encontraron movimientos registrados para las fechas o filtros seleccionados.</p>
      </div>

      <!-- Tarjetas de Movimientos (Optimizadas para Móvil) -->
      <div v-else class="space-y-4">
        <div 
          v-for="mov in sortedMovimientos" 
          :key="mov.id" 
          class="bg-white rounded-3xl shadow-sm border border-slate-100 overflow-hidden transition-all duration-200 hover:border-slate-200"
        >
          <!-- Header de Tarjeta (Siempre visible) -->
          <div 
            @click="toggleExpand(mov.id)"
            class="p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 cursor-pointer select-none"
          >
            <div class="space-y-1">
              <div class="flex items-center gap-2">
                <span class="text-xs font-extrabold px-2.5 py-0.5 bg-slate-900 text-white rounded-full font-mono">
                  #{{ mov.id }}
                </span>
                <span class="text-xs text-slate-400 font-mono">
                  {{ new Date(mov.created_at).toLocaleDateString(undefined, { day: '2-digit', month: 'short', year: 'numeric' }) }}
                </span>
              </div>
              <p class="font-bold text-slate-800 text-base">{{ mov.clientes?.nombre }}</p>
            </div>
            
            <div class="flex items-center justify-between sm:justify-end gap-4 border-t sm:border-t-0 pt-2 sm:pt-0 border-slate-50">
              <div class="text-left sm:text-right">
                <span class="text-[10px] text-slate-400 font-bold uppercase tracking-wider block">Equipos</span>
                <span class="text-xs font-semibold text-slate-700 bg-slate-50 border border-slate-100 px-2 py-0.5 rounded-lg">
                  {{ mov.movimientos_equipos?.length || 0 }}
                </span>
              </div>
              <div class="text-left sm:text-right">
                <span class="text-[10px] text-slate-400 font-bold uppercase tracking-wider block">Repuestos</span>
                <span class="text-xs font-semibold text-slate-700 bg-slate-50 border border-slate-100 px-2 py-0.5 rounded-lg">
                  {{ mov.movimientos_productos?.length || 0 }}
                </span>
              </div>
              <div v-if="mov.incluye_software" class="text-left sm:text-right">
                <span class="text-[10px] text-slate-400 font-bold uppercase tracking-wider block">Software</span>
                <span class="text-xs font-semibold text-indigo-700 bg-indigo-50 border border-indigo-100 px-2 py-0.5 rounded-lg">
                  Sí
                </span>
              </div>
              <div class="text-slate-400 pl-2">
                <ChevronDown v-if="!expandedMovimientos[mov.id]" class="h-5 w-5" />
                <ChevronUp v-else class="h-5 w-5" />
              </div>
            </div>
          </div>

          <!-- Cuerpo Expandido de Tarjeta (Detalles) -->
          <div 
            v-if="expandedMovimientos[mov.id]" 
            class="px-5 pb-5 pt-3 border-t border-slate-50 bg-slate-50/50 space-y-4 text-sm animate-in slide-in-from-top-1 duration-150"
          >
            <!-- Cliente info -->
            <div class="bg-white border border-slate-100 rounded-2xl p-3.5 space-y-2.5">
              <div class="flex items-center justify-between">
                <span class="text-xs font-extrabold uppercase tracking-wider text-slate-400 block">Datos del Cliente</span>
                <a 
                  v-if="mov.clientes?.telefono"
                  :href="`tel:${mov.clientes.telefono}`" 
                  class="flex items-center gap-1 text-xs text-slate-600 hover:text-slate-950 font-bold transition-colors bg-slate-50 px-2 py-1 rounded-lg border border-slate-100"
                >
                  <Phone class="h-3 w-3" />
                  Llamar
                </a>
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-2 text-xs">
                <div>
                  <span class="text-slate-400 block">Teléfono</span>
                  <span class="font-semibold text-slate-800 font-mono">{{ mov.clientes?.telefono || '—' }}</span>
                </div>
                <div>
                  <span class="text-slate-400 block">RIF</span>
                  <span class="font-semibold text-slate-800 font-mono">{{ mov.clientes?.rif || '—' }}</span>
                </div>
                <div>
                  <span class="text-slate-400 block">Domicilio Fiscal</span>
                  <span class="font-semibold text-slate-800">{{ mov.clientes?.ubicacion_geografica || '—' }}</span>
                </div>
              </div>
            </div>

            <!-- Descripción -->
            <div v-if="mov.descripcion" class="space-y-1 bg-white border border-slate-100 rounded-2xl p-3.5">
              <span class="text-xs font-extrabold uppercase tracking-wider text-slate-400 block">Descripción del Trabajo</span>
              <p class="text-slate-700 leading-relaxed">{{ mov.descripcion }}</p>
            </div>

            <!-- Equipos -->
            <div class="space-y-2">
              <span class="text-xs font-extrabold uppercase tracking-wider text-slate-400 block px-1">Equipos Atendidos</span>
              <div class="space-y-2">
                <div 
                  v-for="me in mov.movimientos_equipos" 
                  :key="me.id"
                  class="bg-white border border-slate-100 rounded-2xl p-3.5 flex items-center justify-between gap-3 shadow-sm"
                >
                  <div class="flex items-center gap-3">
                    <div class="p-2 bg-slate-50 border border-slate-100 rounded-xl text-slate-600">
                      <Cpu class="h-4 w-4" />
                    </div>
                    <div>
                      <p class="font-bold text-slate-800 text-xs">{{ me.equipos?.marcas?.nombre || 'Marca Desconocida' }}</p>
                      <p class="text-[11px] text-slate-500">Modelo: {{ me.equipos?.modelo }}</p>
                    </div>
                  </div>
                  <div class="text-right">
                    <span class="text-[10px] text-slate-400 font-bold uppercase tracking-wider block">Número de Serie</span>
                    <span class="text-xs font-semibold text-slate-800 font-mono bg-slate-100 px-2 py-0.5 rounded-lg border border-slate-200">
                      {{ me.nro_serie || 'Sin Serial' }}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Repuestos -->
            <div v-if="mov.movimientos_productos?.length > 0" class="space-y-2">
              <span class="text-xs font-extrabold uppercase tracking-wider text-slate-400 block px-1">Repuestos Utilizados</span>
              <div class="space-y-2">
                <div 
                  v-for="mp in mov.movimientos_productos" 
                  :key="mp.id"
                  class="bg-white border border-slate-100 rounded-2xl p-3.5 flex items-center justify-between gap-3 shadow-sm"
                >
                  <div class="flex items-center gap-3">
                    <div class="p-2 bg-slate-50 border border-slate-100 rounded-xl text-slate-600">
                      <Wrench class="h-4 w-4" />
                    </div>
                    <div>
                      <p class="font-bold text-slate-800 text-xs">{{ mp.repuestos?.nombre }}</p>
                      <p v-if="mp.repuestos?.codigo_barras" class="text-[10px] text-slate-400 font-mono">
                        {{ mp.repuestos.codigo_barras }}
                      </p>
                    </div>
                  </div>
                  <div class="text-right">
                    <span class="text-[10px] text-slate-400 font-bold uppercase tracking-wider block">Cantidad</span>
                    <span class="text-xs font-bold text-slate-800 bg-slate-100 border border-slate-200 px-2.5 py-0.5 rounded-lg">
                      x{{ mp.cantidad }}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Licencias -->
            <div v-if="mov.movimientos_licencias?.length > 0" class="space-y-2">
              <span class="text-xs font-extrabold uppercase tracking-wider text-slate-400 block px-1">Licencias Instaladas</span>
              <div class="space-y-2">
                <div 
                  v-for="ml in mov.movimientos_licencias" 
                  :key="ml.id"
                  class="bg-white border border-slate-100 rounded-2xl p-3.5 flex items-center justify-between gap-3 shadow-sm"
                >
                  <div class="flex items-center gap-3">
                    <div class="p-2 bg-slate-50 border border-slate-100 rounded-xl text-slate-650">
                      <Key class="h-4 w-4" />
                    </div>
                    <div>
                      <p class="font-bold text-slate-800 text-xs">{{ ml.licencias?.nombre || 'Licencia Desconocida' }}</p>
                    </div>
                  </div>
                  <div class="text-right">
                    <span class="text-[10px] text-slate-400 font-bold uppercase tracking-wider block">Clave / Key</span>
                    <span class="text-xs font-semibold text-slate-850 font-mono bg-slate-100 px-2 py-0.5 rounded-lg border border-slate-200">
                      {{ ml.key }}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Reporte Imprimible (Oculto en pantalla, se muestra en print) -->
    <div class="print-report hidden print:block bg-white text-black p-4 md:p-8 font-sans w-full">
      <!-- Header del reporte -->
      <div class="flex justify-between items-start border-b-2 border-slate-900 pb-4 mb-6">
        <div>
          <h1 class="text-xl font-black uppercase tracking-tighter leading-none mb-2">Reporte Histórico de Movimientos</h1>
          <div class="flex flex-wrap gap-4 text-[9px] font-bold text-slate-600">
             <p>EMITIDO: {{ formatDateTime(new Date()) }}</p>
             <p>FILTROS ACTIVOS: <span class="text-slate-955">{{ activeFiltersSummary }}</span></p>
          </div>
        </div>
        <div class="text-right">
           <p class="text-base font-black leading-none">Medic Play</p>
           <p class="text-[9px] uppercase font-bold text-slate-500">Histórico de Taller</p>
        </div>
      </div>

      <!-- Tabla -->
      <table class="w-full border-collapse border border-slate-300">
        <thead>
          <tr class="bg-slate-100 border-b border-slate-300 text-[8px] font-black uppercase">
            <th class="p-1.5 text-center w-12 border-r border-slate-300">ID</th>
            <th class="p-1.5 text-left w-28 border-r border-slate-300">Fecha</th>
            <th class="p-1.5 text-left w-36 border-r border-slate-300">Cliente</th>
            <th class="p-1.5 text-left border-r border-slate-300">Equipos & Seriales</th>
            <th class="p-1.5 text-left border-r border-slate-300">Repuestos & Licencias</th>
            <th class="p-1.5 text-left">Trabajo Realizado</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="mov in sortedMovimientos" :key="mov.id" class="border-b border-slate-200 page-break-inside-avoid">
            <td class="p-1.5 text-center text-[10px] font-bold border-r border-slate-200">{{ mov.id }}</td>
            <td class="p-1.5 text-[9px] font-mono border-r border-slate-200">
              {{ new Date(mov.created_at).toLocaleString() }}
            </td>
            <td class="p-1.5 text-[9px] border-r border-slate-200">
              <p class="font-bold text-slate-900">{{ mov.clientes?.nombre }}</p>
              <p class="text-[8px] text-slate-500 font-mono" v-if="mov.clientes?.telefono">Tel: {{ mov.clientes.telefono }}</p>
            </td>
            <td class="p-1.5 text-[8px] border-r border-slate-200 space-y-1">
              <div v-for="me in mov.movimientos_equipos" :key="me.id" class="leading-tight">
                <span class="font-bold text-slate-800">{{ me.equipos?.marcas?.nombre }} {{ me.equipos?.modelo }}</span>
                <span class="text-slate-500 block">S/N: <span class="font-mono">{{ me.nro_serie || '—' }}</span></span>
              </div>
            </td>
            <td class="p-1.5 text-[8px] border-r border-slate-200 space-y-1">
              <div v-if="mov.movimientos_productos?.length > 0" class="space-y-0.5 pb-1">
                <p class="font-bold text-slate-500 uppercase text-[6px] tracking-wider mb-0.5">Repuestos:</p>
                <div v-for="mp in mov.movimientos_productos" :key="mp.id" class="leading-tight">
                  • {{ mp.repuestos?.nombre }} <span class="font-bold">(x{{ mp.cantidad }})</span>
                </div>
              </div>
              <div v-if="mov.movimientos_licencias?.length > 0" class="space-y-0.5 border-t border-slate-100 pt-1">
                <p class="font-bold text-slate-500 uppercase text-[6px] tracking-wider mb-0.5">Licencias:</p>
                <div v-for="ml in mov.movimientos_licencias" :key="ml.id" class="leading-tight">
                  • {{ ml.licencias?.nombre }} <span class="font-semibold font-mono text-[6px]">({{ ml.key }})</span>
                </div>
              </div>
              <span v-if="(!mov.movimientos_productos || mov.movimientos_productos.length === 0) && (!mov.movimientos_licencias || mov.movimientos_licencias.length === 0)" class="text-slate-400 font-medium">—</span>
            </td>
            <td class="p-1.5 text-[9px] text-slate-700 leading-normal">{{ mov.descripcion || '—' }}</td>
          </tr>
        </tbody>
      </table>

      <!-- Pie de página -->
      <div class="mt-8 pt-6 border-t border-slate-200 flex justify-between items-end text-[8px] font-bold text-slate-400">
         <div>
            <p>ESTE DOCUMENTO ES UN REGISTRO HISTÓRICO DE CONTROL INTERNO DE SERVICIOS - MEDIC PLAY.</p>
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
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }
}
</style>
