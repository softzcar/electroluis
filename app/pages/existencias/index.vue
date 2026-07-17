<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { useSupabaseClient } from '#imports'
import { useBarcodeScanner } from '~/composables/useBarcodeScanner'
import { 
  Package, Tags, MapPin, Barcode, Search, ChevronDown, ChevronUp, 
  X, Filter, RefreshCw, Eye, Calendar, Users, Cpu, Phone, Printer
} from 'lucide-vue-next'

const supabase = useSupabaseClient()

// Fuentes de datos
const repuestos = ref<any[]>([])
const categorias = ref<any[]>([])
const loading = ref(false)
const errorMsg = ref('')

// Filtros reactivos
const repuestoSearchQuery = ref('')
const selectedRepuesto = ref<any | null>(null)
const showRepuestoDropdown = ref(false)

const categoryQuery = ref('')
const selectedCategory = ref<any | null>(null)
const showCategoryDropdown = ref(false)

const locationQuery = ref('')
const selectedLocation = ref<string | null>(null)
const showLocationDropdown = ref(false)

// Estado del Modal de Trazabilidad
const activeRepuesto = ref<any | null>(null)
const showTraceModal = ref(false)
const traceLoading = ref(false)
const traceError = ref('')
const traceMovements = ref<any[]>([])
const expandedMovementsInModal = ref<Record<number, boolean>>({})

// Cargar catálogos iniciales
const loadData = async () => {
  loading.value = true
  errorMsg.value = ''
  
  try {
    const [
      { data: repData, error: repErr },
      { data: catData, error: catErr }
    ] = await Promise.all([
      supabase.from('repuestos').select('*, categorias(nombre)').is('deleted_at', null).order('nombre'),
      supabase.from('categorias').select('*').is('deleted_at', null).order('nombre')
    ])

    if (repErr) throw repErr
    if (catErr) throw catErr

    repuestos.value = repData ?? []
    categorias.value = catData ?? []
  } catch (err: any) {
    errorMsg.value = err.message || 'Error al obtener los repuestos.'
  } finally {
    loading.value = false
  }
}

onMounted(loadData)

// Escáner de código de barras
useBarcodeScanner((code) => {
  repuestoSearchQuery.value = code
})

// --- LÓGICA DE AUTOCOMPLETADOS ---

// Autocompletado de Repuestos (por nombre o código de barras)
const filteredSearchRepuestos = computed(() => {
  if (!repuestoSearchQuery.value) return []
  const q = repuestoSearchQuery.value.toLowerCase()
  return repuestos.value.filter(r => 
    r.nombre?.toLowerCase().includes(q) || 
    r.codigo_barras?.toLowerCase() === q
  )
})

const selectRepuesto = (rep: any) => {
  selectedRepuesto.value = rep
  repuestoSearchQuery.value = ''
  showRepuestoDropdown.value = false
}

// Autocompletado de Categorías
const filteredCategories = computed(() => {
  if (!categoryQuery.value) return categorias.value
  const q = categoryQuery.value.toLowerCase()
  return categorias.value.filter(c => c.nombre?.toLowerCase().includes(q))
})

const selectCategory = (cat: any) => {
  selectedCategory.value = cat
  categoryQuery.value = ''
  showCategoryDropdown.value = false
}

// Ubicaciones dinámicas (únicas y ordenadas de los repuestos cargados)
const uniqueLocations = computed(() => {
  const locs = repuestos.value
    .map(r => r.ubicacion?.trim())
    .filter(Boolean) as string[]
  return Array.from(new Set(locs)).sort((a, b) => a.localeCompare(b))
})

const filteredLocations = computed(() => {
  if (!locationQuery.value) return uniqueLocations.value
  const q = locationQuery.value.toLowerCase()
  return uniqueLocations.value.filter(l => l.toLowerCase().includes(q))
})

const selectLocation = (loc: string) => {
  selectedLocation.value = loc
  locationQuery.value = ''
  showLocationDropdown.value = false
}

// Limpiar filtros específicos
const clearRepuesto = () => { selectedRepuesto.value = null }
const clearCategory = () => { selectedCategory.value = null }
const clearLocation = () => { selectedLocation.value = null }

const clearAllFilters = () => {
  selectedRepuesto.value = null
  selectedCategory.value = null
  selectedLocation.value = null
  repuestoSearchQuery.value = ''
  categoryQuery.value = ''
  locationQuery.value = ''
}

// --- FILTRADO CLIENT-SIDE ---
const filteredRepuestos = computed(() => {
  return repuestos.value.filter(r => {
    // 1. Filtro por repuesto seleccionado
    if (selectedRepuesto.value) {
      if (r.id !== selectedRepuesto.value.id) return false
    } else if (repuestoSearchQuery.value.trim()) {
      // Si hay texto escrito pero no seleccionado, también filtramos en tiempo real
      const q = repuestoSearchQuery.value.trim().toLowerCase()
      const matchesName = r.nombre?.toLowerCase().includes(q)
      const matchesBarcode = r.codigo_barras?.toLowerCase() === q
      if (!matchesName && !matchesBarcode) return false
    }

    // 2. Filtro por categoría
    if (selectedCategory.value) {
      if (r.id_categoria !== selectedCategory.value.id) return false
    }

    // 3. Filtro por ubicación
    if (selectedLocation.value) {
      if (r.ubicacion?.trim() !== selectedLocation.value) return false
    }

    return true
  })
})

// --- DETALLES DE TRAZABILIDAD (MODAL) ---
const openTraceabilityModal = async (repuesto: any) => {
  activeRepuesto.value = repuesto
  showTraceModal.value = true
  traceLoading.value = true
  traceError.value = ''
  traceMovements.value = []
  expandedMovementsInModal.value = {}

  try {
    const { data, error } = await supabase
      .from('movimientos_productos')
      .select(`
        cantidad,
        movimientos (
          id,
          descripcion,
          created_at,
          clientes (
            id,
            nombre,
            telefono,
            ubicacion_geografica
          ),
          movimientos_equipos (
            id,
            nro_serie,
            equipos (
              id,
              modelo,
              marcas (
                id,
                nombre
              )
            )
          )
        )
      `)
      .eq('id_repuesto', repuesto.id)
      .order('id', { ascending: false })

    if (error) throw error

    traceMovements.value = (data ?? []).map((item: any) => ({
      cantidadUtilizada: item.cantidad,
      id: item.movimientos?.id,
      descripcion: item.movimientos?.descripcion,
      created_at: item.movimientos?.created_at,
      cliente: item.movimientos?.clientes,
      equipos: item.movimientos?.movimientos_equipos?.map((me: any) => ({
        nro_serie: me.nro_serie,
        modelo: me.equipos?.modelo,
        marca: me.equipos?.marcas?.nombre
      }))
    }))
  } catch (err: any) {
    traceError.value = err.message || 'Error al obtener los detalles de trazabilidad.'
  } finally {
    traceLoading.value = false
  }
}

const toggleExpandTrace = (id: number) => {
  expandedMovementsInModal.value[id] = !expandedMovementsInModal.value[id]
}

// --- ORDENACIÓN ---
const sortBy = ref('nombre')
const sortOrder = ref<'asc' | 'desc'>('asc')

const setSort = (field: string) => {
  if (sortBy.value === field) {
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortBy.value = field
    sortOrder.value = 'asc'
  }
}

const sortedRepuestos = computed(() => {
  const list = [...filteredRepuestos.value]
  return list.sort((a, b) => {
    let valA = ''
    let valB = ''

    if (sortBy.value === 'nombre') {
      valA = a.nombre || ''
      valB = b.nombre || ''
    } else if (sortBy.value === 'categoria') {
      valA = a.categorias?.nombre || ''
      valB = b.categorias?.nombre || ''
    } else if (sortBy.value === 'ubicacion') {
      valA = a.ubicacion || ''
      valB = b.ubicacion || ''
    } else if (sortBy.value === 'cantidad') {
      const numA = a.cantidad ?? 0
      const numB = b.cantidad ?? 0
      return sortOrder.value === 'asc' ? numA - numB : numB - numA
    }

    return sortOrder.value === 'asc' 
      ? valA.localeCompare(valB) 
      : valB.localeCompare(valA)
  })
})

// --- IMPRESIÓN ---
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
  if (selectedRepuesto.value) parts.push(`Repuesto: "${selectedRepuesto.value.nombre}"`)
  else if (repuestoSearchQuery.value.trim()) parts.push(`Búsqueda: "${repuestoSearchQuery.value.trim()}"`)
  if (selectedCategory.value) parts.push(`Categoría: "${selectedCategory.value.nombre}"`)
  if (selectedLocation.value) parts.push(`Ubicación: "${selectedLocation.value}"`)
  return parts.length > 0 ? parts.join(' | ') : 'Todos los repuestos (Sin filtros)'
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
          <Package class="h-6 w-6" />
        </div>
        <div>
          <h1 class="text-2xl font-bold text-slate-800">Existencias</h1>
          <p class="text-xs text-slate-500">Reporte de stock actual de repuestos e historial de uso</p>
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
          @click="loadData"
          class="p-2.5 bg-white border border-slate-200 text-slate-700 hover:bg-slate-50 rounded-2xl transition-colors shadow-sm flex items-center gap-2 text-sm font-semibold"
        >
          <RefreshCw class="h-4 w-4" :class="{ 'animate-spin': loading }" />
          <span class="hidden sm:inline">Actualizar</span>
        </button>
      </div>
    </div>

    <!-- Panel de Filtros -->
    <div class="bg-white rounded-3xl shadow-sm border border-slate-100 p-6 space-y-6">
      <div class="flex items-center gap-2 pb-3 border-b border-slate-50">
        <Filter class="h-5 w-5 text-slate-600" />
        <span class="font-bold text-slate-800">Filtros del Reporte</span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
        <!-- Buscar Repuesto (Typeahead / Barcode) -->
        <div class="space-y-2 relative">
          <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
            <Search class="h-3.5 w-3.5" /> Buscar Repuesto
          </label>
          <div v-if="selectedRepuesto" class="flex items-center justify-between bg-slate-50 border border-slate-200 px-3.5 py-2.5 rounded-xl text-sm font-semibold">
            <span class="truncate text-slate-800">{{ selectedRepuesto.nombre }}</span>
            <button @click="clearRepuesto" class="text-slate-400 hover:text-red-500 transition-colors p-0.5">
              <X class="h-4 w-4" />
            </button>
          </div>
          <div v-else class="relative">
            <input 
              v-model="repuestoSearchQuery"
              type="text"
              placeholder="Nombre o escanea barras..."
              @focus="showRepuestoDropdown = true"
              class="w-full pl-3 pr-9 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
            >
            <Barcode class="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
            
            <!-- Dropdown -->
            <div v-if="showRepuestoDropdown && repuestoSearchQuery" class="absolute left-0 right-0 mt-1 bg-white rounded-xl shadow-xl border border-slate-100 z-50 max-h-48 overflow-y-auto">
              <div 
                v-for="r in filteredSearchRepuestos" 
                :key="r.id" 
                @click="selectRepuesto(r)"
                class="px-4 py-2 hover:bg-slate-50 cursor-pointer text-sm border-b border-slate-50 last:border-0 truncate"
              >
                <p class="font-bold text-slate-800">{{ r.nombre }}</p>
                <p class="text-[10px] text-slate-400 font-mono">{{ r.codigo_barras || 'Sin código' }}</p>
              </div>
              <div v-if="filteredSearchRepuestos.length === 0" class="px-4 py-3 text-xs text-slate-400 text-center">
                Sin coincidencias
              </div>
            </div>
          </div>
        </div>

        <!-- Categoría (Typeahead) -->
        <div class="space-y-2 relative">
          <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
            <Tags class="h-3.5 w-3.5" /> Categoría
          </label>
          <div v-if="selectedCategory" class="flex items-center justify-between bg-slate-50 border border-slate-200 px-3.5 py-2.5 rounded-xl text-sm font-semibold">
            <span class="truncate text-slate-800">{{ selectedCategory.nombre }}</span>
            <button @click="clearCategory" class="text-slate-400 hover:text-red-500 transition-colors p-0.5">
              <X class="h-4 w-4" />
            </button>
          </div>
          <div v-else>
            <input 
              v-model="categoryQuery"
              type="text"
              placeholder="Buscar categoría..."
              @focus="showCategoryDropdown = true"
              class="w-full px-3.5 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
            >
            <!-- Dropdown -->
            <div v-if="showCategoryDropdown" class="absolute left-0 right-0 mt-1 bg-white rounded-xl shadow-xl border border-slate-100 z-50 max-h-48 overflow-y-auto">
              <div 
                v-for="c in filteredCategories" 
                :key="c.id" 
                @click="selectCategory(c)"
                class="px-4 py-2 hover:bg-slate-50 cursor-pointer text-sm border-b border-slate-50 last:border-0 truncate font-semibold"
              >
                {{ c.nombre }}
              </div>
            </div>
          </div>
        </div>

        <!-- Ubicación (Typeahead) -->
        <div class="space-y-2 relative">
          <label class="text-xs font-bold text-slate-600 uppercase tracking-wider flex items-center gap-1.5">
            <MapPin class="h-3.5 w-3.5" /> Ubicación
          </label>
          <div v-if="selectedLocation" class="flex items-center justify-between bg-slate-50 border border-slate-200 px-3.5 py-2.5 rounded-xl text-sm font-semibold">
            <span class="truncate text-slate-800">{{ selectedLocation }}</span>
            <button @click="clearLocation" class="text-slate-400 hover:text-red-500 transition-colors p-0.5">
              <X class="h-4 w-4" />
            </button>
          </div>
          <div v-else>
            <input 
              v-model="locationQuery"
              type="text"
              placeholder="Buscar ubicación..."
              @focus="showLocationDropdown = true"
              class="w-full px-3.5 py-2.5 border border-slate-200 rounded-xl focus:ring-2 focus:ring-slate-900 focus:outline-none transition-shadow text-sm"
            >
            <!-- Dropdown -->
            <div v-if="showLocationDropdown" class="absolute left-0 right-0 mt-1 bg-white rounded-xl shadow-xl border border-slate-100 z-50 max-h-48 overflow-y-auto">
              <div 
                v-for="l in filteredLocations" 
                :key="l" 
                @click="selectLocation(l)"
                class="px-4 py-2 hover:bg-slate-50 cursor-pointer text-sm border-b border-slate-50 last:border-0 truncate font-semibold"
              >
                {{ l }}
              </div>
              <div v-if="filteredLocations.length === 0" class="px-4 py-3 text-xs text-slate-400 text-center">
                Sin ubicaciones registradas
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Botón Limpiar -->
      <div class="flex justify-end pt-2 border-t border-slate-100">
        <button 
          @click="clearAllFilters"
          class="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-semibold rounded-xl transition-colors text-xs"
        >
          Limpiar Filtros
        </button>
      </div>
    </div>

    <!-- Resultados -->
    <div class="space-y-4">
      <div class="flex items-center justify-between px-2">
        <h2 class="text-lg font-bold text-slate-800">
          Listado de Repuestos 
          <span class="text-xs text-slate-400 font-normal ml-1">
            (mostrando {{ sortedRepuestos.length }} de {{ repuestos.length }})
          </span>
        </h2>
      </div>

      <!-- Spinner de Carga -->
      <div v-if="loading" class="bg-white rounded-3xl p-12 text-center border border-slate-100">
        <RefreshCw class="h-8 w-8 animate-spin mx-auto text-slate-400 mb-3" />
        <p class="text-sm text-slate-500 font-medium">Cargando existencias...</p>
      </div>

      <!-- Error -->
      <div v-else-if="errorMsg" class="bg-red-50 border border-red-100 rounded-3xl p-6 text-red-700 text-sm">
        {{ errorMsg }}
      </div>

      <!-- Sin Resultados -->
      <div v-else-if="sortedRepuestos.length === 0" class="bg-white rounded-3xl p-12 text-center border border-slate-100 shadow-sm">
        <Package class="h-10 w-10 text-slate-300 mx-auto mb-3" />
        <p class="text-slate-800 font-bold mb-1">Sin repuestos</p>
        <p class="text-xs text-slate-500 max-w-sm mx-auto">No se encontraron repuestos con los filtros seleccionados.</p>
      </div>

      <!-- Tabla / Lista de Repuestos -->
      <div v-else class="bg-white rounded-3xl shadow-sm border border-slate-100 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-sm text-left">
            <thead class="bg-slate-50 text-slate-600 border-b border-slate-100 font-semibold select-none">
              <tr>
                <th class="px-6 py-4 cursor-pointer hover:bg-slate-100/50 transition-colors" @click="setSort('nombre')">
                  Nombre (Insumo) <span v-if="sortBy === 'nombre'">{{ sortOrder === 'asc' ? '▲' : '▼' }}</span>
                </th>
                <th class="px-6 py-4 cursor-pointer hover:bg-slate-100/50 transition-colors" @click="setSort('categoria')">
                  Categoría <span v-if="sortBy === 'categoria'">{{ sortOrder === 'asc' ? '▲' : '▼' }}</span>
                </th>
                <th class="px-6 py-4 cursor-pointer hover:bg-slate-100/50 transition-colors" @click="setSort('ubicacion')">
                  Ubicación <span v-if="sortBy === 'ubicacion'">{{ sortOrder === 'asc' ? '▲' : '▼' }}</span>
                </th>
                <th class="px-6 py-4">Código de Barras</th>
                <th class="px-6 py-4 text-center cursor-pointer hover:bg-slate-100/50 transition-colors" @click="setSort('cantidad')">
                  Existencias <span v-if="sortBy === 'cantidad'">{{ sortOrder === 'asc' ? '▲' : '▼' }}</span>
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr 
                v-for="rep in sortedRepuestos" 
                :key="rep.id" 
                class="hover:bg-slate-50/50 transition-colors"
              >
                <!-- Nombre del repuesto (clickable) -->
                <td class="px-6 py-4 font-bold text-slate-800">
                  <button 
                    @click="openTraceabilityModal(rep)"
                    class="text-left text-slate-900 hover:text-slate-700 hover:underline flex items-center gap-1.5 group"
                    title="Ver trazabilidad de uso"
                  >
                    {{ rep.nombre }}
                    <Eye class="h-3.5 w-3.5 text-slate-400 group-hover:text-slate-700 opacity-0 group-hover:opacity-100 transition-all shrink-0" />
                  </button>
                </td>
                
                <td class="px-6 py-4 text-slate-500 font-medium">
                  {{ rep.categorias?.nombre || 'Sin Categoría' }}
                </td>
                
                <td class="px-6 py-4 font-mono text-xs text-slate-600">
                  {{ rep.ubicacion || '—' }}
                </td>
                
                <td class="px-6 py-4 font-mono text-xs text-slate-400">
                  {{ rep.codigo_barras || '—' }}
                </td>
                
                <!-- Stock Badge -->
                <td class="px-6 py-4 text-center">
                  <span 
                    v-if="rep.cantidad === 0" 
                    class="inline-block px-2.5 py-0.5 text-xs font-bold bg-red-50 text-red-700 border border-red-100 rounded-full"
                  >
                    Agotado
                  </span>
                  <span 
                    v-else-if="rep.cantidad <= 5" 
                    class="inline-block px-2.5 py-0.5 text-xs font-bold bg-amber-50 text-amber-700 border border-amber-100 rounded-full"
                  >
                    {{ rep.cantidad }} (Bajo)
                  </span>
                  <span 
                    v-else 
                    class="inline-block px-2.5 py-0.5 text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-100 rounded-full"
                  >
                    {{ rep.cantidad }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- MODAL: Trazabilidad de uso (Secciones colapsables de movimientos) -->
    <div v-if="showTraceModal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="bg-white rounded-3xl w-full max-w-2xl shadow-2xl border border-slate-100 flex flex-col max-h-[85vh] animate-in zoom-in-95 duration-200">
        <!-- Modal Header -->
        <div class="p-6 border-b border-slate-100 flex items-center justify-between">
          <div class="flex items-center gap-2">
            <Package class="h-5 w-5 text-slate-600" />
            <div>
              <h3 class="text-lg font-bold text-slate-900">Trazabilidad de Repuesto</h3>
              <p class="text-xs text-slate-500 font-semibold truncate max-w-md">{{ activeRepuesto?.nombre }}</p>
            </div>
          </div>
          <button @click="showTraceModal = false" class="p-1 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-50 transition-all">
            <X class="h-5 w-5" />
          </button>
        </div>

        <!-- Modal Body (Listado) -->
        <div class="p-6 overflow-y-auto flex-1 space-y-4 min-h-[250px]">
          <!-- Carga -->
          <div v-if="traceLoading" class="text-center py-12">
            <RefreshCw class="h-8 w-8 animate-spin mx-auto text-slate-400 mb-2" />
            <p class="text-xs text-slate-500 font-medium">Buscando historial de movimientos...</p>
          </div>

          <!-- Error -->
          <div v-else-if="traceError" class="bg-red-50 border border-red-100 rounded-2xl p-4 text-red-700 text-xs">
            {{ traceError }}
          </div>

          <!-- Sin uso en movimientos -->
          <div v-else-if="traceMovements.length === 0" class="text-center py-12">
            <History class="h-10 w-10 text-slate-300 mx-auto mb-2" />
            <p class="text-sm font-bold text-slate-800">Sin registros de uso</p>
            <p class="text-xs text-slate-500">Este insumo no se ha utilizado en ningún trabajo registrado hasta el momento.</p>
          </div>

          <!-- Movimientos en los que se usó (Secciones Colapsables) -->
          <div v-else class="space-y-3">
            <div 
              v-for="item in traceMovements" 
              :key="item.id"
              class="border border-slate-100 rounded-2xl overflow-hidden shadow-sm bg-white"
            >
              <!-- Cabecera Colapsable -->
              <div 
                @click="toggleExpandTrace(item.id)"
                class="p-4 flex items-center justify-between cursor-pointer select-none bg-slate-50/50 hover:bg-slate-50 transition-colors"
              >
                <div class="flex items-center gap-2">
                  <span class="text-xs font-bold font-mono px-2 py-0.5 bg-slate-900 text-white rounded-full">
                    #{{ item.id }}
                  </span>
                  <span class="font-bold text-slate-800 text-sm truncate max-w-[200px] sm:max-w-xs">
                    {{ item.cliente?.nombre }}
                  </span>
                </div>
                <div class="flex items-center gap-3">
                  <span class="text-[11px] font-extrabold bg-blue-50 text-blue-700 border border-blue-100 px-2 py-0.5 rounded-lg shrink-0">
                    Usado: {{ item.cantidadUtilizada }} ud.
                  </span>
                  <div class="text-slate-400">
                    <ChevronDown v-if="!expandedMovementsInModal[item.id]" class="h-4 w-4" />
                    <ChevronUp v-else class="h-4 w-4" />
                  </div>
                </div>
              </div>

              <!-- Contenido Expandido -->
              <div 
                v-if="expandedMovementsInModal[item.id]" 
                class="p-4 border-t border-slate-100 bg-white space-y-3.5 text-xs animate-in slide-in-from-top-1 duration-150"
              >
                <!-- Fecha -->
                <div>
                  <span class="text-[10px] text-slate-400 font-bold uppercase tracking-wider block">Fecha del Movimiento</span>
                  <span class="font-semibold text-slate-700 font-mono">
                    {{ new Date(item.created_at).toLocaleString() }}
                  </span>
                </div>

                <!-- Cliente Detalles -->
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 bg-slate-50 rounded-xl p-3 border border-slate-100">
                  <div>
                    <span class="text-[9px] text-slate-400 font-bold uppercase tracking-wider block">Contacto Cliente</span>
                    <a 
                      v-if="item.cliente?.telefono"
                      :href="`tel:${item.cliente.telefono}`" 
                      class="inline-flex items-center gap-1 font-bold text-slate-700 hover:text-slate-950 font-mono"
                    >
                      <Phone class="h-3 w-3" />
                      {{ item.cliente.telefono }}
                    </a>
                    <span v-else class="text-slate-400">—</span>
                  </div>
                  <div>
                    <span class="text-[9px] text-slate-400 font-bold uppercase tracking-wider block">Dirección</span>
                    <span class="font-semibold text-slate-700">{{ item.cliente?.ubicacion_geografica || '—' }}</span>
                  </div>
                </div>

                <!-- Descripción del Servicio -->
                <div>
                  <span class="text-[10px] text-slate-400 font-bold uppercase tracking-wider block">Descripción del Trabajo</span>
                  <p class="text-slate-700 leading-relaxed font-medium bg-slate-50/50 p-2.5 rounded-xl border border-slate-100/50">
                    {{ item.descripcion || '—' }}
                  </p>
                </div>

                <!-- Equipos reparados en este movimiento -->
                <div class="space-y-1.5">
                  <span class="text-[10px] text-slate-400 font-bold uppercase tracking-wider block">Equipos Reparados en esta Orden</span>
                  <div class="grid grid-cols-1 gap-2">
                    <div 
                      v-for="(eq, eqIdx) in item.equipos" 
                      :key="eqIdx"
                      class="flex items-center justify-between bg-slate-50/50 p-2.5 rounded-xl border border-slate-100"
                    >
                      <div class="flex items-center gap-2">
                        <Cpu class="h-3.5 w-3.5 text-slate-400" />
                        <span class="font-semibold text-slate-700">{{ eq.marca }} {{ eq.modelo }}</span>
                      </div>
                      <div>
                        <span class="text-[9px] text-slate-400 font-bold uppercase tracking-wider mr-1.5">S/N:</span>
                        <span class="font-mono text-slate-800 bg-white border border-slate-200 px-1.5 py-0.5 rounded-md font-semibold">
                          {{ eq.nro_serie || 'Sin Serial' }}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Modal Footer -->
        <div class="p-6 border-t border-slate-100 flex justify-end">
          <button 
            @click="showTraceModal = false"
            class="px-4 py-2 bg-slate-900 hover:bg-slate-800 text-white rounded-xl text-sm font-semibold transition-colors shadow-sm"
          >
            Cerrar
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- Reporte Imprimible (Oculto en pantalla, se muestra en print) -->
  <div class="print-report hidden print:block bg-white text-black p-4 md:p-8 font-sans w-full">
    <!-- Header del reporte -->
    <div class="flex justify-between items-start border-b-2 border-slate-900 pb-4 mb-6">
      <div>
        <h1 class="text-xl font-black uppercase tracking-tighter leading-none mb-2">Reporte de Existencias (Stock)</h1>
        <div class="flex flex-wrap gap-4 text-[9px] font-bold text-slate-600">
           <p>EMITIDO: {{ formatDateTime(new Date()) }}</p>
           <p>FILTROS ACTIVOS: <span class="text-slate-955">{{ activeFiltersSummary }}</span></p>
        </div>
      </div>
      <div class="text-right">
         <p class="text-base font-black leading-none">Medic Play</p>
         <p class="text-[9px] uppercase font-bold text-slate-500">Control de Inventario</p>
      </div>
    </div>

    <!-- Tabla -->
    <table class="w-full border-collapse border border-slate-300">
      <thead>
        <tr class="bg-slate-100 border-b border-slate-300 text-[8px] font-black uppercase">
          <th class="p-1.5 text-left border-r border-slate-300">Nombre (Insumo)</th>
          <th class="p-1.5 text-left w-36 border-r border-slate-300">Categoría</th>
          <th class="p-1.5 text-left w-36 border-r border-slate-300">Ubicación</th>
          <th class="p-1.5 text-left w-36 border-r border-slate-300">Código de Barras</th>
          <th class="p-1.5 text-center w-24">Cantidad</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="rep in sortedRepuestos" :key="rep.id" class="border-b border-slate-200 page-break-inside-avoid">
          <td class="p-1.5 text-[9px] font-bold text-slate-900 border-r border-slate-200">{{ rep.nombre }}</td>
          <td class="p-1.5 text-[9px] text-slate-600 border-r border-slate-200 font-medium">
            {{ rep.categorias?.nombre || 'Sin Categoría' }}
          </td>
          <td class="p-1.5 text-[9px] font-mono text-slate-700 border-r border-slate-200">
            {{ rep.ubicacion || '—' }}
          </td>
          <td class="p-1.5 text-[9px] font-mono text-slate-400 border-r border-slate-200">
            {{ rep.codigo_barras || '—' }}
          </td>
          <td class="p-1.5 text-center text-[10px] font-black" :class="rep.cantidad === 0 ? 'text-red-600 font-bold' : ''">
            {{ rep.cantidad }}
          </td>
        </tr>
      </tbody>
    </table>

    <!-- Pie de página -->
    <div class="mt-8 pt-6 border-t border-slate-200 flex justify-between items-end text-[8px] font-bold text-slate-400">
       <div>
          <p>ESTE DOCUMENTO ES UN REGISTRO DE STOCK Y EXISTENCIAS DE REPUESTOS - MEDIC PLAY.</p>
       </div>
       <div class="text-right">
          Página ____ de ____
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
