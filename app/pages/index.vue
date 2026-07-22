<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { useSupabaseClient, useSupabaseUser } from '#imports'
import { useBarcodeScanner } from '~/composables/useBarcodeScanner'
import { Users, Cpu, Wrench, Search, Trash2, Plus, Minus, Barcode, ClipboardList, Check, AlertTriangle } from 'lucide-vue-next'

const supabase = useSupabaseClient()
const user = useSupabaseUser()

// Fuentes de datos
const clientes = ref<any[]>([])
const equipos = ref<any[]>([])
const repuestos = ref<any[]>([])

const loading = ref(false)
const submitting = ref(false)
const errorMsg = ref('')
const successMsg = ref('')

// Estado del formulario
const form = reactive({
  descripcion: ''
})

// Estados de búsquedas / Typeaheads
const clientQuery = ref('')
const selectedClient = ref<any | null>(null)
const showClientDropdown = ref(false)

const equipQuery = ref('')
const showEquipDropdown = ref(false)
const selectedEquipos = ref<any[]>([]) // { id, marca, modelo, nro_serie }

const repuestoQuery = ref('')
const showRepuestoDropdown = ref(false)
const selectedRepuestos = ref<any[]>([]) // { id, nombre, codigo_barras, cantidad, stock }

// Estados de los Modales
const showClientModal = ref(false)
const showEquipmentModal = ref(false)
const showRepuestoModal = ref(false)

// Cargar catálogos iniciales
const loadData = async () => {
  loading.value = true
  const [
    { data: cl, error: clErr },
    { data: eq, error: eqErr },
    { data: rep, error: repErr }
  ] = await Promise.all([
    supabase.from('clientes').select('*').is('deleted_at', null).order('nombre'),
    supabase.from('equipos').select('*, marcas(nombre)').is('deleted_at', null),
    supabase.from('repuestos').select('*').is('deleted_at', null).order('nombre')
  ])

  if (clErr) errorMsg.value = clErr.message
  if (eqErr) errorMsg.value = eqErr.message
  if (repErr) errorMsg.value = repErr.message

  clientes.value = cl ?? []
  equipos.value = (eq ?? []).sort((a: any, b: any) => (a.marcas?.nombre || '').localeCompare(b.marcas?.nombre || ''))
  repuestos.value = rep ?? []
  loading.value = false
}

onMounted(loadData)

// Filtros para autocompletado
const filteredClientes = computed(() => {
  if (!clientQuery.value) return []
  const q = clientQuery.value.toLowerCase()
  return clientes.value.filter(c => 
    c.nombre?.toLowerCase().includes(q) || 
    c.telefono?.includes(q) ||
    c.rif?.toLowerCase().includes(q)
  )
})

const filteredEquipos = computed(() => {
  if (!equipQuery.value) return []
  const q = equipQuery.value.toLowerCase()
  return equipos.value.filter(e => 
    e.marcas?.nombre?.toLowerCase().includes(q) || 
    e.modelo?.toLowerCase().includes(q)
  )
})

const filteredRepuestos = computed(() => {
  if (!repuestoQuery.value) return []
  const q = repuestoQuery.value.toLowerCase()
  return repuestos.value.filter(r => 
    r.nombre?.toLowerCase().includes(q) || 
    r.codigo_barras?.toLowerCase().includes(q)
  )
})

// Manejo de selecciones
const selectClient = (cli: any) => {
  selectedClient.value = cli
  clientQuery.value = ''
  showClientDropdown.value = false
}

const removeClient = () => {
  selectedClient.value = null
}

const addEquipment = (eq: any) => {
  if (!selectedEquipos.value.find(item => item.id === eq.id)) {
    selectedEquipos.value.push({
      id: eq.id,
      marca: eq.marcas?.nombre || eq.marca,
      modelo: eq.modelo,
      nro_serie: ''
    })
  }
  equipQuery.value = ''
  showEquipDropdown.value = false
}

const removeEquipment = (index: number) => {
  selectedEquipos.value.splice(index, 1)
}

const addRepuesto = (rep: any) => {
  if (rep.cantidad <= 0) {
    errorMsg.value = `No hay existencias disponibles para el repuesto: ${rep.nombre}.`
    setTimeout(() => {
      if (errorMsg.value.includes('No hay existencias')) {
        errorMsg.value = ''
      }
    }, 4000)
    repuestoQuery.value = ''
    showRepuestoDropdown.value = false
    return
  }

  const existing = selectedRepuestos.value.find(item => item.id === rep.id)
  if (existing) {
    if (existing.cantidad < rep.cantidad) {
      existing.cantidad++
    }
  } else {
    selectedRepuestos.value.push({
      id: rep.id,
      nombre: rep.nombre,
      codigo_barras: rep.codigo_barras,
      cantidad: 1,
      stock: rep.cantidad
    })
  }
  repuestoQuery.value = ''
  showRepuestoDropdown.value = false
}

const removeRepuesto = (index: number) => {
  selectedRepuestos.value.splice(index, 1)
}

const incrementRepuesto = (index: number) => {
  const item = selectedRepuestos.value[index]
  if (item.cantidad < item.stock) {
    item.cantidad++
  }
}

const decrementRepuesto = (index: number) => {
  const item = selectedRepuestos.value[index]
  if (item.cantidad > 1) {
    item.cantidad--
  } else {
    removeRepuesto(index)
  }
}

// Handlers de creación en modales
const onClientCreated = (newClient: any) => {
  clientes.value.push(newClient)
  selectedClient.value = newClient
  showClientModal.value = false
}

const onEquipmentCreated = (newEquip: any) => {
  equipos.value.push(newEquip)
  addEquipment(newEquip)
  showEquipmentModal.value = false
}

const onRepuestoCreated = (newRep: any) => {
  repuestos.value.push(newRep)
  addRepuesto(newRep)
  showRepuestoModal.value = false
}

// Integración del lector de código de barras
useBarcodeScanner((code) => {
  const found = repuestos.value.find(r => r.codigo_barras === code)
  if (found) {
    addRepuesto(found)
    successMsg.value = `Escaneado: ${found.nombre}`
    setTimeout(() => {
      successMsg.value = ''
    }, 3000)
  } else {
    errorMsg.value = `Código no registrado: "${code}"`
    setTimeout(() => {
      errorMsg.value = ''
    }, 4000)
  }
})

// Registro final del movimiento
const submitMovement = async () => {
  if (!selectedClient.value) {
    errorMsg.value = 'Debes seleccionar un cliente.'
    return
  }

  if (selectedEquipos.value.length === 0) {
    errorMsg.value = 'Debes agregar al menos un equipo.'
    return
  }

  // Verificar números de serie vacíos
  for (const eq of selectedEquipos.value) {
    if (!eq.nro_serie.trim()) {
      errorMsg.value = `El equipo ${eq.marca} ${eq.modelo} requiere un número de serie.`
      return
    }
  }

  // VALIDACIÓN: Asegurarse de que el número de serie de los equipos no se repita en el mismo movimiento
  const serials = selectedEquipos.value.map(eq => eq.nro_serie.trim().toLowerCase())
  const hasDuplicates = serials.some((val, i) => serials.indexOf(val) !== i)
  if (hasDuplicates) {
    errorMsg.value = 'No se permiten números de serie duplicados en el mismo movimiento.'
    return
  }

  errorMsg.value = ''
  successMsg.value = ''
  submitting.value = true

  try {
    // Obtener el ID del usuario de forma segura (con fallback a la API de Supabase si es necesario)
    let userId = user.value?.id
    if (!userId) {
      const { data: { user: currentUser } } = await supabase.auth.getUser()
      userId = currentUser?.id
    }

    if (!userId) {
      throw new Error('No se pudo determinar el usuario autenticado. Por favor, inicia sesión de nuevo.')
    }

    // 1. Insertar movimiento principal
    const { data: movData, error: movErr } = await supabase
      .from('movimientos')
      .insert({
        id_cliente: selectedClient.value.id,
        id_user: userId,
        descripcion: form.descripcion || null
      })
      .select()
      .single()

    if (movErr) throw new Error(movErr.message)
    const newMovId = movData.id

    // 2. Insertar equipos del movimiento con sus números de serie
    const equipInserts = selectedEquipos.value.map(eq => ({
      id_movimiento: newMovId,
      id_equipo: eq.id,
      nro_serie: eq.nro_serie
    }))

    const { error: eqRelErr } = await supabase
      .from('movimientos_equipos')
      .insert(equipInserts)

    if (eqRelErr) throw new Error(eqRelErr.message)

    // 3. Insertar repuestos y descontar stock
    if (selectedRepuestos.value.length > 0) {
      const prodInserts = selectedRepuestos.value.map(rep => ({
        id_movimiento: newMovId,
        id_repuesto: rep.id,
        cantidad: rep.cantidad
      }))

      const { error: prodRelErr } = await supabase
        .from('movimientos_productos')
        .insert(prodInserts)

      if (prodRelErr) throw new Error(prodRelErr.message)

      // Actualizar el stock en la base de datos
      for (const rep of selectedRepuestos.value) {
        const newQty = rep.stock - rep.cantidad
        const { error: stockErr } = await supabase
          .from('repuestos')
          .update({ cantidad: newQty })
          .eq('id', rep.id)
        
        if (stockErr) console.error(`Error actualizando stock para ${rep.nombre}:`, stockErr.message)
      }
    }

    // Resetear formulario
    form.descripcion = ''
    selectedClient.value = null
    selectedEquipos.value = []
    selectedRepuestos.value = []
    successMsg.value = '¡Movimiento registrado con éxito!'
    
    await loadData()

    setTimeout(() => {
      successMsg.value = ''
    }, 4000)

  } catch (err: any) {
    errorMsg.value = err.message || 'Error registrando el movimiento.'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="max-w-6xl mx-auto px-4 py-6 space-y-8 animate-fade-in">
    
    <!-- Encabezado -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-200 pb-5">
      <div>
        <h1 class="text-3xl font-extrabold text-slate-900 tracking-tight flex items-center gap-3">
          <span class="bg-gradient-to-r from-slate-900 to-slate-700 bg-clip-text text-transparent">
            Registro de Movimientos
          </span>
        </h1>
        <p class="text-sm text-slate-500 mt-1">
          Crea un nuevo servicio técnico asociando un cliente, equipos, números de serie y repuestos.
        </p>
      </div>
      <div v-if="successMsg" class="flex items-center gap-2 bg-emerald-50 text-emerald-800 border border-emerald-200 px-4 py-2.5 rounded-xl text-sm shadow-sm">
        <Check class="h-4 w-4 text-emerald-600" />
        <span>{{ successMsg }}</span>
      </div>
    </div>

    <!-- Alerta del Lector de Código de Barras -->
    <div class="bg-slate-950 text-slate-100 px-4 py-3 rounded-2xl flex items-center justify-between shadow-xl">
      <div class="flex items-center gap-3">
        <span class="relative flex h-3 w-3">
          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-cyan-400 opacity-75"></span>
          <span class="relative inline-flex rounded-full h-3 w-3 bg-cyan-500"></span>
        </span>
        <div class="flex items-center gap-2">
          <Barcode class="h-5 w-5 text-cyan-400" />
          <span class="text-xs font-semibold uppercase tracking-wider text-slate-400">Escáner de código de barras:</span>
          <span class="text-sm font-medium">Activo globalmente. Escanee un repuesto en cualquier momento.</span>
        </div>
      </div>
    </div>

    <!-- Formulario Principal -->
    <form @submit.prevent="submitMovement" novalidate class="grid grid-cols-1 lg:grid-cols-12 gap-8">
      
      <!-- COLUMNA IZQUIERDA: Cliente, Equipos, Descripción (7 cols) -->
      <div class="lg:col-span-7 space-y-6">
        
        <!-- CARD: Cliente -->
        <div class="bg-white rounded-3xl p-6 shadow-sm border border-slate-100 space-y-4">
          <h2 class="text-lg font-bold text-slate-800 flex items-center gap-2">
            <Users class="h-5 w-5 text-slate-600" />
            1. Cliente del Servicio
          </h2>

          <div v-if="!selectedClient" class="flex gap-2">
            <div class="relative flex-1">
              <Search class="absolute left-3 top-3 h-5 w-5 text-slate-400" />
              <input
                v-model="clientQuery"
                type="text"
                @focus="showClientDropdown = true"
                @blur="setTimeout(() => showClientDropdown = false, 200)"
                placeholder="Buscar cliente por nombre o teléfono..."
                class="w-full pl-10 pr-4 py-2.5 border border-slate-200 rounded-2xl focus:ring-2 focus:ring-slate-950 focus:outline-none bg-slate-50 focus:bg-white transition-all text-sm"
              >
              
              <!-- Lista de sugerencias de Clientes -->
              <div 
                v-if="showClientDropdown && clientQuery" 
                class="absolute z-50 w-full mt-2 bg-white border border-slate-100 rounded-2xl shadow-xl max-h-60 overflow-y-auto divide-y divide-slate-100"
              >
                <div 
                  v-for="cli in filteredClientes" 
                  :key="cli.id"
                  @mousedown="selectClient(cli)"
                  class="px-4 py-3 hover:bg-slate-50 cursor-pointer transition-colors flex justify-between items-center text-sm"
                >
                  <div>
                    <p class="font-semibold text-slate-800">{{ cli.nombre }}</p>
                    <p class="text-xs text-slate-500 font-medium" v-if="cli.rif">RIF: {{ cli.rif }}</p>
                    <p class="text-xs text-slate-400">{{ cli.ubicacion_geografica || 'Sin domicilio fiscal' }}</p>
                  </div>
                  <span class="text-xs bg-slate-100 text-slate-600 px-2.5 py-1 rounded-full font-mono">
                    {{ cli.telefono || 'Sin teléfono' }}
                  </span>
                </div>
                <div v-if="filteredClientes.length === 0" class="px-4 py-4 text-center text-sm text-slate-400">
                  No se encontraron clientes con "{{ clientQuery }}"
                </div>
              </div>
            </div>
            
            <button 
              type="button"
              @click="showClientModal = true"
              class="bg-slate-100 hover:bg-slate-200 text-slate-700 p-3 rounded-2xl border border-slate-200 flex items-center justify-center transition-colors shrink-0"
              title="Crear nuevo cliente"
            >
              <Plus class="h-5 w-5" />
            </button>
          </div>

          <!-- Cliente Seleccionado -->
          <div 
            v-else 
            class="bg-slate-50 border border-slate-100 rounded-2xl p-4 flex items-center justify-between"
          >
            <div class="flex items-center gap-3">
              <div class="h-10 w-10 bg-slate-900 text-white rounded-xl flex items-center justify-center font-bold">
                {{ selectedClient.nombre.charAt(0).toUpperCase() }}
              </div>
              <div>
                <p class="font-bold text-slate-800 text-sm">{{ selectedClient.nombre }}</p>
                <p class="text-xs text-slate-500">
                  <span v-if="selectedClient.rif" class="font-semibold">RIF: {{ selectedClient.rif }} • </span>
                  {{ selectedClient.telefono || 'Sin teléfono' }} • {{ selectedClient.ubicacion_geografica || 'Sin domicilio fiscal' }}
                </p>
              </div>
            </div>
            <button 
              type="button"
              @click="removeClient"
              class="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-xl transition-all"
            >
              <Trash2 class="h-5 w-5" />
            </button>
          </div>
        </div>

        <!-- CARD: Equipos -->
        <div class="bg-white rounded-3xl p-6 shadow-sm border border-slate-100 space-y-4">
          <div class="flex justify-between items-center">
            <h2 class="text-lg font-bold text-slate-800 flex items-center gap-2">
              <Cpu class="h-5 w-5 text-slate-600" />
              2. Equipos Involucrados
            </h2>
            <span class="text-xs bg-slate-100 text-slate-600 px-2.5 py-1 rounded-full font-semibold">
              {{ selectedEquipos.length }} agregados
            </span>
          </div>

          <div class="flex gap-2">
            <div class="relative flex-1">
              <Search class="absolute left-3 top-3 h-5 w-5 text-slate-400" />
              <input
                v-model="equipQuery"
                type="text"
                @focus="showEquipDropdown = true"
                @blur="setTimeout(() => showEquipDropdown = false, 200)"
                placeholder="Buscar equipo en catálogo por marca o modelo..."
                class="w-full pl-10 pr-4 py-2.5 border border-slate-200 rounded-2xl focus:ring-2 focus:ring-slate-950 focus:outline-none bg-slate-50 focus:bg-white transition-all text-sm"
              >
              
              <!-- Lista de sugerencias de Equipos -->
              <div 
                v-if="showEquipDropdown && equipQuery" 
                class="absolute z-50 w-full mt-2 bg-white border border-slate-100 rounded-2xl shadow-xl max-h-60 overflow-y-auto divide-y divide-slate-100"
              >
                <div 
                  v-for="eq in filteredEquipos" 
                  :key="eq.id"
                  @mousedown="addEquipment(eq)"
                  class="px-4 py-3 hover:bg-slate-50 cursor-pointer transition-colors flex justify-between items-center text-sm"
                >
                  <div>
                    <p class="font-bold text-slate-800">{{ eq.marcas?.nombre }}</p>
                    <p class="text-xs text-slate-500">Modelo: {{ eq.modelo }}</p>
                  </div>
                  <span class="text-xs bg-slate-100 text-slate-600 font-semibold px-2.5 py-1 rounded-full">
                    Agregar
                  </span>
                </div>
                <div v-if="filteredEquipos.length === 0" class="px-4 py-4 text-center text-sm text-slate-400">
                  No se encontraron equipos con "{{ equipQuery }}"
                </div>
              </div>
            </div>
            
            <button 
              type="button"
              @click="showEquipmentModal = true"
              class="bg-slate-100 hover:bg-slate-200 text-slate-700 p-3 rounded-2xl border border-slate-200 flex items-center justify-center transition-colors shrink-0"
              title="Crear nuevo equipo en catálogo"
            >
              <Plus class="h-5 w-5" />
            </button>
          </div>

          <!-- Lista de Equipos Seleccionados con Serial -->
          <div v-if="selectedEquipos.length > 0" class="space-y-3 pt-2">
            <div 
              v-for="(eq, index) in selectedEquipos" 
              :key="eq.id" 
              class="bg-slate-50 border border-slate-100 rounded-2xl p-4 space-y-3 relative"
            >
              <div class="flex justify-between items-start">
                <div>
                  <span class="text-xs uppercase font-extrabold tracking-wider text-slate-400">Equipo {{ index + 1 }}</span>
                  <p class="font-bold text-slate-800 text-sm">{{ eq.marca }} - {{ eq.modelo }}</p>
                </div>
                <button 
                  type="button"
                  @click="removeEquipment(index)"
                  class="p-1.5 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-xl transition-all"
                >
                  <Trash2 class="h-4 w-4" />
                </button>
              </div>
              
              <div class="grid grid-cols-1 gap-1">
                <label class="text-xs font-semibold text-slate-500">Número de serie</label>
                <input
                  v-model="eq.nro_serie"
                  type="text"
                  required
                  placeholder="Introduce el número de serie de este aparato..."
                  class="w-full px-3 py-2 border border-slate-200 rounded-xl bg-white focus:ring-2 focus:ring-slate-950 focus:outline-none text-sm font-mono"
                >
              </div>
            </div>
          </div>
          <div v-else class="text-center py-6 text-sm text-slate-400 border border-dashed border-slate-200 rounded-2xl">
            No has agregado ningún equipo aún.
          </div>
        </div>

        <!-- CARD: Descripción del servicio -->
        <div class="bg-white rounded-3xl p-6 shadow-sm border border-slate-100 space-y-3">
          <label class="block text-sm font-bold text-slate-800 font-medium">3. Detalles del Servicio / Falla</label>
          <textarea
            v-model="form.descripcion"
            rows="3"
            placeholder="Ej. Cambio de sensores de temperatura y mantenimiento..."
            class="w-full px-4 py-3 border border-slate-200 rounded-2xl focus:ring-2 focus:ring-slate-950 focus:outline-none bg-slate-50 focus:bg-white transition-all text-sm"
          ></textarea>
        </div>
      </div>

      <!-- COLUMNA DERECHA: Repuestos y Enviar (5 cols) -->
      <div class="lg:col-span-5 space-y-6">
        
        <!-- CARD: Repuestos -->
        <div class="bg-white rounded-3xl p-6 shadow-sm border border-slate-100 space-y-4">
          <div class="flex justify-between items-center">
            <h2 class="text-lg font-bold text-slate-800 flex items-center gap-2">
              <Wrench class="h-5 w-5 text-slate-600" />
              4. Repuestos Utilizados
            </h2>
            <span class="text-xs bg-slate-100 text-slate-600 px-2.5 py-1 rounded-full font-semibold">
              {{ selectedRepuestos.length }} items
            </span>
          </div>

          <!-- Typeahead de Repuestos -->
          <div class="flex gap-2">
            <div class="relative flex-1">
              <Search class="absolute left-3 top-3 h-5 w-5 text-slate-400" />
              <input
                v-model="repuestoQuery"
                type="text"
                @focus="showRepuestoDropdown = true"
                @blur="setTimeout(() => showRepuestoDropdown = false, 200)"
                placeholder="Buscar repuesto por nombre o código..."
                class="w-full pl-10 pr-11 py-2.5 border border-slate-200 rounded-2xl focus:ring-2 focus:ring-slate-950 focus:outline-none bg-slate-50 focus:bg-white transition-all text-sm"
              >
              <Barcode class="absolute right-3.5 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-400" />
              
              <!-- Lista de sugerencias de Repuestos -->
              <div 
                v-if="showRepuestoDropdown && repuestoQuery" 
                class="absolute z-50 w-full mt-2 bg-white border border-slate-100 rounded-2xl shadow-xl max-h-60 overflow-y-auto divide-y divide-slate-100"
              >
                <div 
                  v-for="rep in filteredRepuestos" 
                  :key="rep.id"
                  @mousedown="addRepuesto(rep)"
                  class="px-4 py-3 transition-colors flex justify-between items-center text-sm"
                  :class="rep.cantidad > 0 ? 'hover:bg-slate-50 cursor-pointer' : 'opacity-60 cursor-not-allowed bg-slate-50/50'"
                >
                  <div>
                    <p class="font-bold text-slate-800">{{ rep.nombre }}</p>
                    <p class="text-xs text-slate-400">Código: {{ rep.codigo_barras || '—' }}</p>
                  </div>
                  <div class="text-right">
                    <span 
                      class="text-xs font-semibold px-2.5 py-1 rounded-full font-mono"
                      :class="rep.cantidad > 0 ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-700'"
                    >
                      Cant: {{ rep.cantidad }}
                    </span>
                  </div>
                </div>
                <div v-if="filteredRepuestos.length === 0" class="px-4 py-4 text-center text-sm text-slate-400">
                  No se encontraron repuestos con "{{ repuestoQuery }}"
                </div>
              </div>
            </div>
            
            <button 
              type="button"
              @click="showRepuestoModal = true"
              class="bg-slate-100 hover:bg-slate-200 text-slate-700 p-3 rounded-2xl border border-slate-200 flex items-center justify-center transition-colors shrink-0"
              title="Crear nuevo repuesto"
            >
              <Plus class="h-5 w-5" />
            </button>
          </div>

          <!-- Lista de Repuestos Seleccionados -->
          <div v-if="selectedRepuestos.length > 0" class="divide-y divide-slate-100 max-h-96 overflow-y-auto pr-1">
            <div 
              v-for="(rep, index) in selectedRepuestos" 
              :key="rep.id"
              class="py-3 flex items-center justify-between gap-4"
            >
              <div class="flex-1 min-w-0">
                <p class="font-bold text-slate-800 text-sm truncate">{{ rep.nombre }}</p>
                <p class="text-xs text-slate-400 font-mono">Barras: {{ rep.codigo_barras || '—' }}</p>
                <p class="text-xs text-slate-500 mt-0.5">Stock actual: <span class="font-semibold">{{ rep.stock }}</span></p>
              </div>

              <!-- Controles de Cantidad -->
              <div class="flex items-center gap-1.5 bg-slate-50 p-1 rounded-xl border border-slate-100 shrink-0">
                <button 
                  type="button" 
                  @click="decrementRepuesto(index)"
                  class="p-1 text-slate-500 hover:text-slate-900 hover:bg-slate-200 rounded-lg transition-colors"
                >
                  <Minus class="h-3 w-3" />
                </button>
                <span class="text-xs font-bold w-6 text-center text-slate-800">{{ rep.cantidad }}</span>
                <button 
                  type="button" 
                  @click="incrementRepuesto(index)"
                  :disabled="rep.cantidad >= rep.stock"
                  class="p-1 text-slate-500 hover:text-slate-900 hover:bg-slate-200 rounded-lg transition-colors disabled:opacity-30 disabled:hover:bg-transparent"
                >
                  <Plus class="h-3 w-3" />
                </button>
              </div>

              <!-- Icono papelera para Eliminar -->
              <button 
                type="button" 
                @click="removeRepuesto(index)"
                class="p-2 text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-xl transition-all shrink-0"
              >
                <Trash2 class="h-4 w-4" />
              </button>
            </div>
          </div>
          <div v-else class="text-center py-6 text-sm text-slate-400 border border-dashed border-slate-200 rounded-2xl">
            Ningún repuesto cargado en este movimiento.
          </div>
        </div>

        <!-- Alertas de Error -->
        <div v-if="errorMsg" class="flex items-start gap-2.5 bg-rose-50 text-rose-800 border border-rose-100 px-4 py-3 rounded-2xl text-sm shadow-sm">
          <AlertTriangle class="h-5 w-5 text-rose-600 shrink-0 mt-0.5" />
          <span>{{ errorMsg }}</span>
        </div>

        <!-- Botón de Envío -->
        <button 
          type="submit" 
          :disabled="submitting"
          class="w-full bg-slate-950 hover:bg-slate-900 text-white font-bold py-3 px-6 rounded-2xl transition-all shadow-lg hover:shadow-xl hover:translate-y-[-1px] disabled:opacity-50 disabled:hover:translate-y-0"
        >
          <span v-if="submitting" class="flex items-center justify-center gap-2">
            <svg class="animate-spin h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            Registrando movimiento...
          </span>
          <span v-else class="flex items-center justify-center gap-2">
            <ClipboardList class="h-5 w-5" />
            Registrar Movimiento Completo
          </span>
        </button>
      </div>

    </form>
  </div>

  <!-- MODAL: Crear Cliente -->
  <div v-if="showClientModal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
    <div class="bg-white rounded-3xl p-6 w-full max-w-md shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200">
      <h3 class="text-lg font-bold text-slate-900 mb-4 flex items-center gap-2">
        <Users class="h-5 w-5 text-slate-600" />
        Crear Nuevo Cliente
      </h3>
      <ClientForm @success="onClientCreated" @cancel="showClientModal = false" />
    </div>
  </div>

  <!-- MODAL: Crear Equipo en Catálogo -->
  <div v-if="showEquipmentModal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
    <div class="bg-white rounded-3xl p-6 w-full max-w-md shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200">
      <h3 class="text-lg font-bold text-slate-900 mb-4 flex items-center gap-2">
        <Cpu class="h-5 w-5 text-slate-600" />
        Agregar Equipo al Catálogo
      </h3>
      <EquipmentForm @success="onEquipmentCreated" @cancel="showEquipmentModal = false" />
    </div>
  </div>

  <!-- MODAL: Crear Repuesto -->
  <div v-if="showRepuestoModal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
    <div class="bg-white rounded-3xl p-6 w-full max-w-md shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200">
      <h3 class="text-lg font-bold text-slate-900 mb-4 flex items-center gap-2">
        <Wrench class="h-5 w-5 text-slate-600" />
        Crear Nuevo Repuesto
      </h3>
      <RepuestoForm @success="onRepuestoCreated" @cancel="showRepuestoModal = false" />
    </div>
  </div>
</template>
