<script setup lang="ts">
import { LayoutDashboard, Users, Cpu, Wrench, ClipboardList, Tags, LogOut, Menu as MenuIcon, X as XIcon, Bookmark, History, Package, UserCog, Key } from 'lucide-vue-next'

const supabase = useSupabaseClient()
const router = useRouter()
const route = useRoute()

const isMobileMenuOpen = ref(false)

const links = [
  { to: '/', label: 'Movimientos', icon: ClipboardList },
  { to: '/historico', label: 'Histórico', icon: History },
  { to: '/repuestos', label: 'Repuestos', icon: Wrench },
  { to: '/licencias', label: 'Licencias', icon: Key },
  { to: '/existencias', label: 'Existencias', icon: Package },
  { to: '/clientes', label: 'Clientes', icon: Users },
  { to: '/equipos', label: 'Equipos', icon: Cpu },
  { to: '/categorias', label: 'Categorías de repuestos', icon: Tags },
  { to: '/marcas', label: 'Marcas', icon: Bookmark },
  { to: '/usuarios', label: 'Usuarios', icon: UserCog }
]

const showLogoutConfirm = ref(false)

const logout = () => {
  showLogoutConfirm.value = true
}

const confirmLogout = async () => {
  showLogoutConfirm.value = false
  await supabase.auth.signOut()
  router.push('/login')
}

// Cerrar el menú móvil en cada cambio de ruta
watch(() => route.path, () => {
  isMobileMenuOpen.value = false
})
</script>

<template>
  <div class="min-h-screen flex flex-col md:flex-row bg-slate-100 text-slate-800">
    <!-- Encabezado Móvil (Solo visible en pantallas pequeñas) -->
    <header class="md:hidden flex items-center justify-between bg-slate-900 text-slate-100 px-4 py-3 shadow-md sticky top-0 z-40">
      <button 
        class="p-2 rounded-md hover:bg-slate-800 transition-colors focus:outline-none" 
        @click="isMobileMenuOpen = !isMobileMenuOpen"
        aria-label="Abrir menú"
      >
        <component :is="isMobileMenuOpen ? XIcon : MenuIcon" :size="24" />
      </button>
      <span class="text-lg font-semibold tracking-wide">Medic Play</span>
      <div class="w-10"></div> <!-- Espaciador para centrar el título -->
    </header>

    <!-- Fondo Oscuro Translúcido para Cerrar el Menú en Móvil -->
    <div 
      class="fixed inset-0 bg-black/40 z-40 md:hidden transition-opacity duration-300"
      :class="isMobileMenuOpen ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'"
      @click="isMobileMenuOpen = false"
    ></div>

    <!-- Menú Lateral (Fijo en desktop, deslizable en móvil) -->
    <aside 
      class="fixed inset-y-0 left-0 w-60 bg-slate-900 text-slate-100 flex flex-col z-50 transform transition-transform duration-300 ease-in-out md:relative md:translate-x-0"
      :class="isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full'"
    >
      <div class="px-4 py-5 text-lg font-semibold border-b border-slate-800 flex justify-between items-center">
        <span>Medic Play</span>
        <!-- Botón para cerrar en móvil -->
        <button 
          class="md:hidden p-1.5 rounded-md hover:bg-slate-800 transition-colors focus:outline-none"
          @click="isMobileMenuOpen = false"
        >
          <XIcon :size="20" />
        </button>
      </div>

      <nav class="flex-1 px-2 py-4 space-y-1 overflow-y-auto">
        <NuxtLink
          v-for="link in links"
          :key="link.to"
          :to="link.to"
          class="flex items-center gap-3 px-3 py-2.5 rounded-md text-sm transition-all hover:bg-slate-800"
          active-class="bg-slate-800 text-cyan-400 font-semibold"
        >
          <component :is="link.icon" :size="18" class="text-slate-400 group-hover:text-slate-100" />
          {{ link.label }}
        </NuxtLink>
      </nav>

      <button
        class="flex items-center gap-3 px-3 py-3 m-2 rounded-md text-sm text-red-400 hover:bg-slate-800 hover:text-red-300 transition-colors"
        @click="logout"
      >
        <LogOut :size="18" />
        Cerrar sesión
      </button>
    </aside>

    <!-- Contenido Principal -->
    <main class="flex-1 p-4 sm:p-6 overflow-x-hidden w-full max-w-full">
      <slot />
    </main>

    <!-- MODAL DE CONFIRMACIÓN DE LOGOUT -->
    <div 
      v-if="showLogoutConfirm" 
      class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[100] flex items-center justify-center p-4"
    >
      <div 
        class="bg-white rounded-3xl p-6 max-w-sm w-full shadow-2xl border border-slate-100 animate-in zoom-in-95 duration-200"
        @click.stop
      >
        <h3 class="text-lg font-bold text-slate-900 mb-2 flex items-center gap-2">
          <LogOut class="h-5 w-5 text-red-500" />
          ¿Cerrar sesión?
        </h3>
        <p class="text-sm text-slate-500 mb-6">
          ¿Estás seguro de que deseas cerrar tu sesión en Medic Play? Deberás ingresar tus credenciales nuevamente para acceder.
        </p>
        <div class="flex justify-end gap-2.5">
          <button 
            type="button" 
            @click="showLogoutConfirm = false"
            class="px-4 py-2.5 border border-slate-200 rounded-xl text-sm font-semibold hover:bg-slate-50 text-slate-700 transition-all active:scale-[0.98]"
          >
            Cancelar
          </button>
          <button 
            type="button" 
            @click="confirmLogout"
            class="px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white rounded-xl text-sm font-semibold transition-all active:scale-[0.98] shadow-md hover:shadow-red-600/20"
          >
            Cerrar sesión
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
